/**
 * Journal ViewModel - Encrypted journaling with search and organization
 *
 * Manages journal metadata from JournalSlice while coordinating
 * with SecureStorage for encrypted content retrieval.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { useCallback, useMemo, useState } from 'react';
import { useAppStore } from '../stores';
import {
  selectFilteredJournals,
  selectJournalSearchResults,
  selectJournalsByTag,
  selectJournalsByMood,
} from '../stores/selectors/journalSelectors';
import type {
  JournalMetadata,
  CreateJournalInput,
  JournalDraft,
  JournalSearchFilters,
} from '../types';

/**
 * Journal ViewModel - Therapeutic journaling interface
 *
 * Usage:
 * ```typescript
 * const {
 *   journals, searchResults, tags,
 *   createJournal, updateJournal, deleteJournal,
 *   searchJournals, filterByTag, filterByMood,
 *   saveDraft, loadDraft,
 *   isLoading
 * } = useJournalViewModel();
 * ```
 */
export const useJournalViewModel = () => {
  // ============================================================================
  // ZUSTAND STORE STATE
  // ============================================================================

  const journalMetadata = useAppStore(selectFilteredJournals);
  const searchResults = useAppStore(selectJournalSearchResults);
  const drafts = useAppStore((state) => state.drafts);
  const tags = useAppStore((state) => state.tags);
  const searchHistory = useAppStore((state) => state.searchHistory);
  const searchFilters = useAppStore((state) => state.searchFilters);
  const loading = useAppStore((state) => state.loading);

  // Store actions
  const addJournalMetadata = useAppStore((state) => state.addJournalMetadata);
  const updateJournalMetadata = useAppStore((state) => state.updateJournalMetadata);
  const deleteJournalMetadata = useAppStore((state) => state.deleteJournalMetadata);
  const toggleFavorite = useAppStore((state) => state.toggleFavorite);
  const createDraft = useAppStore((state) => state.createDraft);
  const updateDraft = useAppStore((state) => state.updateDraft);
  const deleteDraft = useAppStore((state) => state.deleteDraft);
  const addTag = useAppStore((state) => state.addTag);
  const removeTag = useAppStore((state) => state.removeTag);
  const setSearchFilters = useAppStore((state) => state.setSearchFilters);
  const addSearchHistory = useAppStore((state) => state.addSearchHistory);

  // ============================================================================
  // LOCAL STATE FOR ENCRYPTION
  // ============================================================================

  const [decryptedContent, setDecryptedContent] = useState<
    Record<string, string>
  >({});
  const [encryptionError, setEncryptionError] = useState<string | null>(null);

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /**
   * Journal statistics
   */
  const journalStats = useMemo(() => {
    const totalEntries = journalMetadata.length;
    const favorites = journalMetadata.filter((j) => j.is_favorite).length;
    const totalWords = journalMetadata.reduce((sum, j) => sum + j.word_count, 0);
    const avgWordsPerEntry = totalEntries > 0 ? Math.round(totalWords / totalEntries) : 0;

    // Tag distribution
    const tagCounts = new Map<string, number>();
    journalMetadata.forEach((journal) => {
      journal.tags.forEach((tag) => {
        tagCounts.set(tag, (tagCounts.get(tag) || 0) + 1);
      });
    });

    const topTags = Array.from(tagCounts.entries())
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .map(([tag, count]) => ({ tag, count }));

    return {
      totalEntries,
      favorites,
      totalWords,
      avgWordsPerEntry,
      topTags,
      activeDrafts: drafts.length,
    };
  }, [journalMetadata, drafts.length]);

  /**
   * Recent journals (last 7 days)
   */
  const recentJournals = useMemo(() => {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    return journalMetadata.filter(
      (j) => new Date(j.created_at) >= sevenDaysAgo
    );
  }, [journalMetadata]);

  /**
   * Loading state
   */
  const isLoading = useMemo(() => {
    return loading.entries || loading.search || loading.encryption;
  }, [loading]);

  // ============================================================================
  // JOURNAL CRUD OPERATIONS
  // ============================================================================

  /**
   * Create new journal entry with client-side encryption
   */
  const createJournal = useCallback(
    async (input: CreateJournalInput) => {
      try {
        // Generate journal metadata
        const metadata: JournalMetadata = {
          id: `temp-${Date.now()}`,
          user_id: input.user_id,
          title: input.title,
          tags: input.tags || [],
          word_count: countWords(input.content),
          mood_level: input.mood_level,
          is_favorite: false,
          is_synced: false,
          created_at: new Date(),
          updated_at: new Date(),
        };

        // Add metadata to store (instant UI feedback)
        addJournalMetadata(metadata);

        // TODO: Encrypt content and store in SecureStorage
        // const encryptedContent = await encryptContent(input.content, metadata.id);
        // await SecureStorage.setItem(`journal_${metadata.id}`, encryptedContent);

        // TODO: Sync to Supabase (metadata only, encrypted content stays local)
        // await JournalRepository.create(metadata);

        return metadata;
      } catch (error) {
        setEncryptionError((error as Error).message);
        throw error;
      }
    },
    [addJournalMetadata]
  );

  /**
   * Update existing journal entry
   */
  const updateJournal = useCallback(
    async (id: string, updates: Partial<CreateJournalInput>) => {
      try {
        const metadataUpdates: Partial<JournalMetadata> = {
          title: updates.title,
          tags: updates.tags,
          mood_level: updates.mood_level,
          updated_at: new Date(),
        };

        if (updates.content) {
          metadataUpdates.word_count = countWords(updates.content);
          // TODO: Re-encrypt and update SecureStorage
          // const encryptedContent = await encryptContent(updates.content, id);
          // await SecureStorage.setItem(`journal_${id}`, encryptedContent);
        }

        updateJournalMetadata(id, metadataUpdates);

        // TODO: Sync metadata to Supabase
        // await JournalRepository.update(id, metadataUpdates);
      } catch (error) {
        setEncryptionError((error as Error).message);
        throw error;
      }
    },
    [updateJournalMetadata]
  );

  /**
   * Delete journal entry (metadata + encrypted content)
   */
  const deleteJournal = useCallback(
    async (id: string) => {
      try {
        // Remove from store
        deleteJournalMetadata(id);

        // TODO: Delete from SecureStorage
        // await SecureStorage.removeItem(`journal_${id}`);

        // TODO: Delete from Supabase
        // await JournalRepository.delete(id);

        // Clear decrypted cache
        setDecryptedContent((prev) => {
          const updated = { ...prev };
          delete updated[id];
          return updated;
        });
      } catch (error) {
        throw error;
      }
    },
    [deleteJournalMetadata]
  );

  /**
   * Toggle favorite status
   */
  const toggleJournalFavorite = useCallback(
    async (id: string) => {
      toggleFavorite(id);

      try {
        // TODO: Sync to Supabase
        // const journal = journalMetadata.find(j => j.id === id);
        // await JournalRepository.update(id, { is_favorite: journal?.is_favorite });
      } catch (error) {
        // Rollback on error
        toggleFavorite(id);
        throw error;
      }
    },
    [toggleFavorite]
  );

  // ============================================================================
  // CONTENT RETRIEVAL & DECRYPTION
  // ============================================================================

  /**
   * Get decrypted journal content
   */
  const getJournalContent = useCallback(
    async (id: string): Promise<string> => {
      // Return cached if available
      if (decryptedContent[id]) {
        return decryptedContent[id];
      }

      try {
        // TODO: Retrieve and decrypt from SecureStorage
        // const encryptedContent = await SecureStorage.getItem(`journal_${id}`);
        // const content = await decryptContent(encryptedContent, id);

        const content = ''; // Placeholder

        // Cache decrypted content
        setDecryptedContent((prev) => ({ ...prev, [id]: content }));

        return content;
      } catch (error) {
        setEncryptionError((error as Error).message);
        throw error;
      }
    },
    [decryptedContent]
  );

  /**
   * Clear decrypted content cache (security measure)
   */
  const clearContentCache = useCallback(() => {
    setDecryptedContent({});
  }, []);

  // ============================================================================
  // SEARCH & FILTERING
  // ============================================================================

  /**
   * Search journals with query
   */
  const searchJournals = useCallback(
    (query: string) => {
      setSearchFilters({ query });
      if (query.trim()) {
        addSearchHistory(query);
      }
    },
    [setSearchFilters, addSearchHistory]
  );

  /**
   * Filter journals by tag
   */
  const filterByTag = useCallback(
    (tag: string) => {
      setSearchFilters({ selectedTags: [tag] });
    },
    [setSearchFilters]
  );

  /**
   * Filter journals by mood level
   */
  const filterByMood = useCallback(
    (moodLevel: number) => {
      setSearchFilters({ moodLevel });
    },
    [setSearchFilters]
  );

  /**
   * Filter journals by date range
   */
  const filterByDateRange = useCallback(
    (startDate: Date | null, endDate: Date | null) => {
      setSearchFilters({ startDate, endDate });
    },
    [setSearchFilters]
  );

  /**
   * Filter favorites only
   */
  const filterFavorites = useCallback(
    (favoritesOnly: boolean) => {
      setSearchFilters({ favoritesOnly });
    },
    [setSearchFilters]
  );

  /**
   * Clear all filters
   */
  const clearFilters = useCallback(() => {
    setSearchFilters({
      query: '',
      selectedTags: [],
      moodLevel: null,
      startDate: null,
      endDate: null,
      favoritesOnly: false,
    });
  }, [setSearchFilters]);

  // ============================================================================
  // DRAFT MANAGEMENT
  // ============================================================================

  /**
   * Save draft for later
   */
  const saveDraft = useCallback(
    (draft: Omit<JournalDraft, 'id' | 'created_at'>) => {
      const newDraft: JournalDraft = {
        id: `draft-${Date.now()}`,
        ...draft,
        created_at: new Date(),
      };

      createDraft(newDraft);
      return newDraft.id;
    },
    [createDraft]
  );

  /**
   * Update existing draft
   */
  const updateExistingDraft = useCallback(
    (id: string, updates: Partial<JournalDraft>) => {
      updateDraft(id, updates);
    },
    [updateDraft]
  );

  /**
   * Delete draft
   */
  const removeDraft = useCallback(
    (id: string) => {
      deleteDraft(id);
    },
    [deleteDraft]
  );

  /**
   * Convert draft to full journal entry
   */
  const publishDraft = useCallback(
    async (draftId: string, userId: string) => {
      const draft = drafts.find((d) => d.id === draftId);
      if (!draft) return;

      const journalInput: CreateJournalInput = {
        user_id: userId,
        title: draft.title,
        content: draft.content,
        tags: draft.tags,
        mood_level: draft.mood_level,
      };

      const journal = await createJournal(journalInput);

      // Remove draft after successful creation
      deleteDraft(draftId);

      return journal;
    },
    [drafts, createJournal, deleteDraft]
  );

  // ============================================================================
  // TAG MANAGEMENT
  // ============================================================================

  /**
   * Add new tag to global list
   */
  const createTag = useCallback(
    (tag: string) => {
      const normalized = tag.toLowerCase().trim();
      if (!tags.includes(normalized)) {
        addTag(normalized);
      }
    },
    [tags, addTag]
  );

  /**
   * Remove tag from global list
   */
  const deleteTag = useCallback(
    (tag: string) => {
      removeTag(tag);
    },
    [removeTag]
  );

  // ============================================================================
  // RETURN VIEWMODEL INTERFACE
  // ============================================================================

  return {
    // Journal data
    journals: journalMetadata,
    searchResults,
    recentJournals,
    journalStats,

    // CRUD operations
    createJournal,
    updateJournal,
    deleteJournal,
    toggleJournalFavorite,
    getJournalContent,
    clearContentCache,

    // Search & filtering
    searchJournals,
    filterByTag,
    filterByMood,
    filterByDateRange,
    filterFavorites,
    clearFilters,
    searchFilters,
    searchHistory,

    // Draft management
    drafts,
    saveDraft,
    updateExistingDraft,
    removeDraft,
    publishDraft,

    // Tag management
    tags,
    createTag,
    deleteTag,

    // Loading & error states
    isLoading,
    encryptionError,
  };
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Count words in text content
 */
function countWords(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

/**
 * Encrypt journal content (placeholder - implement with crypto library)
 */
async function encryptContent(content: string, id: string): Promise<string> {
  // TODO: Implement AES-256 encryption
  return content;
}

/**
 * Decrypt journal content (placeholder - implement with crypto library)
 */
async function decryptContent(encrypted: string, id: string): Promise<string> {
  // TODO: Implement AES-256 decryption
  return encrypted;
}
