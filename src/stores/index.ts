/**
 * Rediscover Talk - Zustand Store
 *
 * Centralized state management with offline-first persistence and type safety.
 * Implements feature-based slices for modular organization across 8 core features.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 * @architecture MVVM-C with Zustand state management
 * @offline-first AsyncStorage persistence with selective data sync
 *
 * Store Architecture:
 * - AuthSlice: User session, authentication state, profile
 * - MoodSlice: Mood entries, analytics, trends
 * - JournalSlice: Journal entries, drafts, search (non-encrypted metadata)
 * - CrisisSlice: Crisis plan metadata, emergency contacts (non-sensitive refs)
 * - PromptsSlice: Daily prompts, responses, completion status
 * - ExercisesSlice: Family exercises, progress tracking
 * - BreathingSlice: Breathing exercises, session history
 * - AIGuideSlice: Conversation history, typing indicators
 *
 * Security Note: Encrypted data (journal content, crisis plan details) stored
 * separately in SecureStorage via repositories. Only metadata persisted here.
 */

import { create } from 'zustand';
import { persist, createJSONStorage, StateStorage } from 'zustand/middleware';
import { devtools } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Slices
import { createAuthSlice, AuthSlice } from './slices/authSlice';
import { createMoodSlice, MoodSlice } from './slices/moodSlice';
import { createJournalSlice, JournalSlice } from './slices/journalSlice';
import { createCrisisSlice, CrisisSlice } from './slices/crisisSlice';
import { createPromptsSlice, PromptsSlice } from './slices/promptsSlice';
import { createExercisesSlice, ExercisesSlice } from './slices/exercisesSlice';
import { createBreathingSlice, BreathingSlice } from './slices/breathingSlice';
import { createAIGuideSlice, AIGuideSlice } from './slices/aiGuideSlice';

// Middleware
import { createSyncMiddleware } from './middleware/syncMiddleware';
import { createLoggingMiddleware } from './middleware/loggingMiddleware';

/**
 * Combined application store type
 */
export type AppStore = AuthSlice &
  MoodSlice &
  JournalSlice &
  CrisisSlice &
  PromptsSlice &
  ExercisesSlice &
  BreathingSlice &
  AIGuideSlice;

/**
 * AsyncStorage wrapper with error handling
 */
const storage: StateStorage = {
  getItem: async (name: string): Promise<string | null> => {
    try {
      const value = await AsyncStorage.getItem(name);
      return value;
    } catch (error) {
      console.error(`AsyncStorage getItem error for ${name}:`, error);
      return null;
    }
  },
  setItem: async (name: string, value: string): Promise<void> => {
    try {
      await AsyncStorage.setItem(name, value);
    } catch (error) {
      console.error(`AsyncStorage setItem error for ${name}:`, error);
    }
  },
  removeItem: async (name: string): Promise<void> => {
    try {
      await AsyncStorage.removeItem(name);
    } catch (error) {
      console.error(`AsyncStorage removeItem error for ${name}:`, error);
    }
  },
};

/**
 * Selective state persistence configuration
 *
 * Strategy:
 * - Persist: User preferences, mood history, prompt responses, exercise progress
 * - Exclude: Authentication tokens (Keychain), encrypted content (SecureStorage)
 * - Sync indicators: Track sync status for offline-first operations
 */
const persistConfig = {
  name: 'rediscover-talk-storage',
  storage: createJSONStorage(() => storage),
  version: 1,

  /**
   * Selective persistence - exclude sensitive data
   */
  partialize: (state: AppStore) => ({
    // Auth: Persist only non-sensitive data
    auth: {
      user: state.user, // User profile (no tokens)
      isAuthenticated: state.isAuthenticated,
      isAnonymous: state.isAnonymous,
      preferences: state.preferences,
    },

    // Mood: Persist all mood entries (non-sensitive)
    mood: {
      entries: state.entries,
      lastSyncedAt: state.lastSyncedAt,
    },

    // Journal: Persist metadata only (content in SecureStorage)
    journal: {
      journalMetadata: state.journalMetadata,
      drafts: state.drafts, // Temporary drafts before save
      tags: state.tags,
      searchHistory: state.searchHistory,
    },

    // Crisis: Persist metadata references (details in SecureStorage)
    crisis: {
      hasCrisisPlan: state.hasCrisisPlan,
      lastReviewedAt: state.lastReviewedAt,
      emergencyContactCount: state.emergencyContactCount,
    },

    // Prompts: Persist responses and completion status
    prompts: {
      responses: state.responses,
      todayPrompt: state.todayPrompt,
      completionStreak: state.completionStreak,
    },

    // Exercises: Persist progress and completions
    exercises: {
      completions: state.completions,
      favoriteExercises: state.favoriteExercises,
      exerciseStreak: state.exerciseStreak,
    },

    // Breathing: Persist session history
    breathing: {
      sessions: state.sessions,
      favoriteExercises: state.favoriteBreathingExercises,
      breathingStreak: state.breathingStreak,
    },

    // AIGuide: Persist conversation metadata (messages in SecureStorage)
    aiGuide: {
      conversationCount: state.conversationCount,
      lastConversationAt: state.lastConversationAt,
      isTyping: state.isTyping,
    },
  }),

  /**
   * Migration strategy for schema changes
   */
  migrate: (persistedState: any, version: number) => {
    if (version === 0) {
      // Migration from initial version to v1
      // Add migration logic if schema changes
    }
    return persistedState as AppStore;
  },

  /**
   * Merge strategy for rehydration
   */
  merge: (persistedState: any, currentState: AppStore) => {
    return {
      ...currentState,
      ...persistedState,
    };
  },
};

/**
 * Main application store
 *
 * Architecture:
 * - Feature-based slices for modularity
 * - Persist middleware for offline-first UX
 * - DevTools middleware for debugging (development only)
 * - Sync middleware for background synchronization
 */
export const useAppStore = create<AppStore>()(
  devtools(
    persist(
      (...a) => ({
        // Auth slice
        ...createAuthSlice(...a),

        // Feature slices
        ...createMoodSlice(...a),
        ...createJournalSlice(...a),
        ...createCrisisSlice(...a),
        ...createPromptsSlice(...a),
        ...createExercisesSlice(...a),
        ...createBreathingSlice(...a),
        ...createAIGuideSlice(...a),
      }),
      persistConfig
    ),
    {
      name: 'RediscoverTalkStore',
      enabled: __DEV__, // Enable DevTools only in development
    }
  )
);

/**
 * Store reset utility (for logout, data wipe)
 */
export const resetStore = async (): Promise<void> => {
  const state = useAppStore.getState();

  // Reset all slices to initial state
  state.logout();
  state.clearMoodEntries();
  state.clearJournalMetadata();
  state.clearCrisisPlan();
  state.clearPromptResponses();
  state.clearExerciseCompletions();
  state.clearBreathingSessions();
  state.clearAIConversations();

  // Clear AsyncStorage
  try {
    await AsyncStorage.removeItem('rediscover-talk-storage');
  } catch (error) {
    console.error('Failed to clear AsyncStorage:', error);
  }
};

/**
 * Export selectors for optimized component subscriptions
 */
export { selectMoodTrends } from './selectors/moodSelectors';
export { selectJournalSearchResults } from './selectors/journalSelectors';
export { selectExerciseProgress } from './selectors/exercisesSelectors';
export { selectBreathingStats } from './selectors/breathingSelectors';

/**
 * Export types for ViewModel consumption
 */
export type {
  AuthSlice,
  MoodSlice,
  JournalSlice,
  CrisisSlice,
  PromptsSlice,
  ExercisesSlice,
  BreathingSlice,
  AIGuideSlice,
};
