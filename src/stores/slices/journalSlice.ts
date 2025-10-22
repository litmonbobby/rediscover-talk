/**
 * Journal Slice - Therapeutic Journaling
 *
 * Manages journal entry metadata, drafts, and search functionality.
 * Encrypted content stored separately in SecureStorage via repositories.
 *
 * Security:
 * - Only metadata (title, tags, word count) stored in Zustand
 * - Encrypted content accessed via JournalRepository
 * - Drafts encrypted before save, cleared on app background
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';

/**
 * Journal entry metadata (non-encrypted)
 */
export interface JournalMetadata {
  id: string;
  user_id: string;
  title: string;
  mood_at_writing: number | null; // 1-5
  tags: string[];
  is_favorite: boolean;
  word_count: number;
  prompt_id: string | null;
  created_at: Date;
  updated_at: Date;
  is_synced: boolean;
}

/**
 * Draft entry (temporary before save)
 */
export interface JournalDraft {
  id: string;
  title: string;
  content: string; // Plaintext until saved
  mood_at_writing: number | null;
  tags: string[];
  created_at: Date;
}

/**
 * Search filters
 */
export interface JournalSearchFilters {
  query: string;
  tags: string[];
  moodRange: [number, number] | null; // [min, max] mood levels
  startDate: Date | null;
  endDate: Date | null;
  favoritesOnly: boolean;
}

/**
 * Loading state
 */
export interface JournalLoadingState {
  isCreating: boolean;
  isUpdating: boolean;
  isDeleting: boolean;
  isSearching: boolean;
  error: string | null;
}

/**
 * Journal Slice Interface
 */
export interface JournalSlice {
  // State
  journalMetadata: JournalMetadata[];
  drafts: JournalDraft[];
  tags: string[]; // All unique tags
  searchHistory: string[]; // Recent search queries
  searchFilters: JournalSearchFilters;
  loading: JournalLoadingState;
  unsyncedEntries: string[];

  // Actions: Metadata operations
  addJournalMetadata: (metadata: JournalMetadata) => void;
  updateJournalMetadata: (id: string, updates: Partial<JournalMetadata>) => void;
  deleteJournalMetadata: (id: string) => void;
  setJournalMetadata: (metadata: JournalMetadata[]) => void;
  clearJournalMetadata: () => void;

  // Actions: Drafts
  createDraft: (draft: JournalDraft) => void;
  updateDraft: (id: string, updates: Partial<JournalDraft>) => void;
  deleteDraft: (id: string) => void;
  clearDrafts: () => void;

  // Actions: Tags
  addTag: (tag: string) => void;
  removeTag: (tag: string) => void;
  updateTags: (tags: string[]) => void;

  // Actions: Search
  setSearchFilters: (filters: Partial<JournalSearchFilters>) => void;
  clearSearchFilters: () => void;
  addSearchQuery: (query: string) => void;
  clearSearchHistory: () => void;

  // Actions: Favorites
  toggleFavorite: (id: string) => void;

  // Actions: Loading states
  setCreating: (isCreating: boolean) => void;
  setUpdating: (isUpdating: boolean) => void;
  setDeleting: (isDeleting: boolean) => void;
  setSearching: (isSearching: boolean) => void;
  setJournalError: (error: string | null) => void;
  clearJournalError: () => void;

  // Actions: Sync
  markJournalAsSynced: (id: string) => void;
  markJournalAsUnsynced: (id: string) => void;
  clearUnsyncedJournals: () => void;

  // Computed: Helpers
  getJournalById: (id: string) => JournalMetadata | undefined;
  getDraftById: (id: string) => JournalDraft | undefined;
  getJournalsByTag: (tag: string) => JournalMetadata[];
  getFavorites: () => JournalMetadata[];
  getRecentEntries: (count: number) => JournalMetadata[];
}

/**
 * Default search filters
 */
const defaultSearchFilters: JournalSearchFilters = {
  query: '',
  tags: [],
  moodRange: null,
  startDate: null,
  endDate: null,
  favoritesOnly: false,
};

/**
 * Default loading state
 */
const defaultLoadingState: JournalLoadingState = {
  isCreating: false,
  isUpdating: false,
  isDeleting: false,
  isSearching: false,
  error: null,
};

/**
 * Create Journal Slice
 */
export const createJournalSlice: StateCreator<JournalSlice> = (set, get) => ({
  // Initial state
  journalMetadata: [],
  drafts: [],
  tags: [],
  searchHistory: [],
  searchFilters: defaultSearchFilters,
  loading: defaultLoadingState,
  unsyncedEntries: [],

  // Metadata actions
  addJournalMetadata: (metadata) =>
    set((state) => ({
      journalMetadata: [metadata, ...state.journalMetadata].sort(
        (a, b) => b.created_at.getTime() - a.created_at.getTime()
      ),
      tags: Array.from(
        new Set([...state.tags, ...metadata.tags])
      ),
      unsyncedEntries: metadata.is_synced
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, metadata.id],
    })),

  updateJournalMetadata: (id, updates) =>
    set((state) => ({
      journalMetadata: state.journalMetadata.map((journal) =>
        journal.id === id
          ? {
              ...journal,
              ...updates,
              updated_at: new Date(),
              is_synced: false,
            }
          : journal
      ),
      tags:
        updates.tags
          ? Array.from(
              new Set([
                ...state.tags,
                ...(updates.tags || []),
              ])
            )
          : state.tags,
      unsyncedEntries: state.unsyncedEntries.includes(id)
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, id],
    })),

  deleteJournalMetadata: (id) =>
    set((state) => ({
      journalMetadata: state.journalMetadata.filter((j) => j.id !== id),
      unsyncedEntries: state.unsyncedEntries.filter((jId) => jId !== id),
    })),

  setJournalMetadata: (metadata) =>
    set(() => ({
      journalMetadata: metadata.sort(
        (a, b) => b.created_at.getTime() - a.created_at.getTime()
      ),
      tags: Array.from(
        new Set(metadata.flatMap((j) => j.tags))
      ),
    })),

  clearJournalMetadata: () =>
    set(() => ({
      journalMetadata: [],
      tags: [],
      unsyncedEntries: [],
    })),

  // Draft actions
  createDraft: (draft) =>
    set((state) => ({
      drafts: [draft, ...state.drafts],
    })),

  updateDraft: (id, updates) =>
    set((state) => ({
      drafts: state.drafts.map((draft) =>
        draft.id === id ? { ...draft, ...updates } : draft
      ),
    })),

  deleteDraft: (id) =>
    set((state) => ({
      drafts: state.drafts.filter((draft) => draft.id !== id),
    })),

  clearDrafts: () => set(() => ({ drafts: [] })),

  // Tag actions
  addTag: (tag) =>
    set((state) => ({
      tags: state.tags.includes(tag) ? state.tags : [...state.tags, tag],
    })),

  removeTag: (tag) =>
    set((state) => ({
      tags: state.tags.filter((t) => t !== tag),
    })),

  updateTags: (tags) => set(() => ({ tags: Array.from(new Set(tags)) })),

  // Search actions
  setSearchFilters: (filters) =>
    set((state) => ({
      searchFilters: { ...state.searchFilters, ...filters },
    })),

  clearSearchFilters: () =>
    set(() => ({
      searchFilters: defaultSearchFilters,
    })),

  addSearchQuery: (query) =>
    set((state) => ({
      searchHistory: [
        query,
        ...state.searchHistory.filter((q) => q !== query),
      ].slice(0, 10), // Keep last 10 searches
    })),

  clearSearchHistory: () => set(() => ({ searchHistory: [] })),

  // Favorites
  toggleFavorite: (id) =>
    set((state) => ({
      journalMetadata: state.journalMetadata.map((journal) =>
        journal.id === id
          ? {
              ...journal,
              is_favorite: !journal.is_favorite,
              updated_at: new Date(),
              is_synced: false,
            }
          : journal
      ),
    })),

  // Loading states
  setCreating: (isCreating) =>
    set((state) => ({
      loading: { ...state.loading, isCreating },
    })),

  setUpdating: (isUpdating) =>
    set((state) => ({
      loading: { ...state.loading, isUpdating },
    })),

  setDeleting: (isDeleting) =>
    set((state) => ({
      loading: { ...state.loading, isDeleting },
    })),

  setSearching: (isSearching) =>
    set((state) => ({
      loading: { ...state.loading, isSearching },
    })),

  setJournalError: (error) =>
    set((state) => ({
      loading: { ...state.loading, error },
    })),

  clearJournalError: () =>
    set((state) => ({
      loading: { ...state.loading, error: null },
    })),

  // Sync actions
  markJournalAsSynced: (id) =>
    set((state) => ({
      journalMetadata: state.journalMetadata.map((journal) =>
        journal.id === id ? { ...journal, is_synced: true } : journal
      ),
      unsyncedEntries: state.unsyncedEntries.filter((jId) => jId !== id),
    })),

  markJournalAsUnsynced: (id) =>
    set((state) => ({
      journalMetadata: state.journalMetadata.map((journal) =>
        journal.id === id ? { ...journal, is_synced: false } : journal
      ),
      unsyncedEntries: state.unsyncedEntries.includes(id)
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, id],
    })),

  clearUnsyncedJournals: () => set(() => ({ unsyncedEntries: [] })),

  // Computed helpers
  getJournalById: (id) => {
    return get().journalMetadata.find((journal) => journal.id === id);
  },

  getDraftById: (id) => {
    return get().drafts.find((draft) => draft.id === id);
  },

  getJournalsByTag: (tag) => {
    return get().journalMetadata.filter((journal) =>
      journal.tags.includes(tag)
    );
  },

  getFavorites: () => {
    return get().journalMetadata.filter((journal) => journal.is_favorite);
  },

  getRecentEntries: (count) => {
    return get().journalMetadata.slice(0, count);
  },
});

/**
 * Selectors
 */
export const selectJournalMetadata = (state: JournalSlice) =>
  state.journalMetadata;
export const selectDrafts = (state: JournalSlice) => state.drafts;
export const selectJournalTags = (state: JournalSlice) => state.tags;
export const selectSearchFilters = (state: JournalSlice) => state.searchFilters;
export const selectFavorites = (state: JournalSlice) => state.getFavorites();
export const selectRecentJournals = (state: JournalSlice, count: number = 5) =>
  state.getRecentEntries(count);
export const selectUnsyncedJournalCount = (state: JournalSlice) =>
  state.unsyncedEntries.length;

/**
 * Filtered journals selector
 */
export const selectFilteredJournals = (state: JournalSlice) => {
  const { journalMetadata, searchFilters } = state;
  let filtered = [...journalMetadata];

  // Text search (title only in metadata; full content search via repository)
  if (searchFilters.query.trim()) {
    const query = searchFilters.query.toLowerCase();
    filtered = filtered.filter((journal) =>
      journal.title.toLowerCase().includes(query)
    );
  }

  // Tag filter
  if (searchFilters.tags.length > 0) {
    filtered = filtered.filter((journal) =>
      searchFilters.tags.some((tag) => journal.tags.includes(tag))
    );
  }

  // Mood range filter
  if (searchFilters.moodRange) {
    const [min, max] = searchFilters.moodRange;
    filtered = filtered.filter(
      (journal) =>
        journal.mood_at_writing !== null &&
        journal.mood_at_writing >= min &&
        journal.mood_at_writing <= max
    );
  }

  // Date range filter
  if (searchFilters.startDate) {
    filtered = filtered.filter(
      (journal) => journal.created_at >= searchFilters.startDate!
    );
  }

  if (searchFilters.endDate) {
    filtered = filtered.filter(
      (journal) => journal.created_at <= searchFilters.endDate!
    );
  }

  // Favorites filter
  if (searchFilters.favoritesOnly) {
    filtered = filtered.filter((journal) => journal.is_favorite);
  }

  return filtered;
};
