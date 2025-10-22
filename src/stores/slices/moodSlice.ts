/**
 * Mood Slice - Wellness Logs & Mood Tracking
 *
 * Manages mood entries, analytics, and trend data.
 * Implements offline-first mood tracking with background sync.
 *
 * Features:
 * - Create, read, update, delete mood entries
 * - Mood trends and analytics
 * - Activity correlation tracking
 * - Sync state management for offline operations
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';
import { MoodEntry, MoodTrend } from '../../types/schemas';

/**
 * Loading state for async operations
 */
export interface MoodLoadingState {
  isCreating: boolean;
  isUpdating: boolean;
  isDeleting: boolean;
  isFetchingTrends: boolean;
  error: string | null;
}

/**
 * Filter options for mood history
 */
export interface MoodFilters {
  startDate: Date | null;
  endDate: Date | null;
  minMoodLevel: number | null; // 1-5
  maxMoodLevel: number | null; // 1-5
  activities: string[];
}

/**
 * Mood Slice Interface
 */
export interface MoodSlice {
  // State
  entries: MoodEntry[];
  trends: MoodTrend | null;
  filters: MoodFilters;
  loading: MoodLoadingState;
  lastSyncedAt: Date | null;
  unsyncedEntries: string[]; // IDs of entries not yet synced

  // Actions: CRUD operations
  addMoodEntry: (entry: MoodEntry) => void;
  updateMoodEntry: (id: string, updates: Partial<MoodEntry>) => void;
  deleteMoodEntry: (id: string) => void;
  setMoodEntries: (entries: MoodEntry[]) => void;
  clearMoodEntries: () => void;

  // Actions: Trends & analytics
  setMoodTrends: (trends: MoodTrend) => void;
  clearMoodTrends: () => void;

  // Actions: Filtering
  setFilters: (filters: Partial<MoodFilters>) => void;
  clearFilters: () => void;

  // Actions: Loading states
  setCreating: (isCreating: boolean) => void;
  setUpdating: (isUpdating: boolean) => void;
  setDeleting: (isDeleting: boolean) => void;
  setFetchingTrends: (isFetching: boolean) => void;
  setMoodError: (error: string | null) => void;
  clearMoodError: () => void;

  // Actions: Sync management
  markAsSynced: (id: string) => void;
  markAsUnsynced: (id: string) => void;
  setLastSynced: (date: Date) => void;
  clearUnsyncedEntries: () => void;

  // Computed: Helpers
  getMoodEntryById: (id: string) => MoodEntry | undefined;
  getMoodEntriesByDateRange: (startDate: Date, endDate: Date) => MoodEntry[];
  getAverageMood: (period: 'week' | 'month' | 'year') => number;
  getMoodStreak: () => number;
}

/**
 * Default filters
 */
const defaultFilters: MoodFilters = {
  startDate: null,
  endDate: null,
  minMoodLevel: null,
  maxMoodLevel: null,
  activities: [],
};

/**
 * Default loading state
 */
const defaultLoadingState: MoodLoadingState = {
  isCreating: false,
  isUpdating: false,
  isDeleting: false,
  isFetchingTrends: false,
  error: null,
};

/**
 * Create Mood Slice
 */
export const createMoodSlice: StateCreator<MoodSlice> = (set, get) => ({
  // Initial state
  entries: [],
  trends: null,
  filters: defaultFilters,
  loading: defaultLoadingState,
  lastSyncedAt: null,
  unsyncedEntries: [],

  // CRUD actions
  addMoodEntry: (entry) =>
    set((state) => ({
      entries: [entry, ...state.entries].sort(
        (a, b) => b.timestamp.getTime() - a.timestamp.getTime()
      ),
      unsyncedEntries: entry.is_synced
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, entry.id],
    })),

  updateMoodEntry: (id, updates) =>
    set((state) => ({
      entries: state.entries.map((entry) =>
        entry.id === id
          ? {
              ...entry,
              ...updates,
              updated_at: new Date(),
              is_synced: false, // Mark as needing sync
            }
          : entry
      ),
      unsyncedEntries: state.unsyncedEntries.includes(id)
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, id],
    })),

  deleteMoodEntry: (id) =>
    set((state) => ({
      entries: state.entries.filter((entry) => entry.id !== id),
      unsyncedEntries: state.unsyncedEntries.filter((entryId) => entryId !== id),
    })),

  setMoodEntries: (entries) =>
    set(() => ({
      entries: entries.sort(
        (a, b) => b.timestamp.getTime() - a.timestamp.getTime()
      ),
    })),

  clearMoodEntries: () =>
    set(() => ({
      entries: [],
      trends: null,
      unsyncedEntries: [],
    })),

  // Trends actions
  setMoodTrends: (trends) => set(() => ({ trends })),
  clearMoodTrends: () => set(() => ({ trends: null })),

  // Filter actions
  setFilters: (filters) =>
    set((state) => ({
      filters: { ...state.filters, ...filters },
    })),

  clearFilters: () => set(() => ({ filters: defaultFilters })),

  // Loading state actions
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

  setFetchingTrends: (isFetchingTrends) =>
    set((state) => ({
      loading: { ...state.loading, isFetchingTrends },
    })),

  setMoodError: (error) =>
    set((state) => ({
      loading: { ...state.loading, error },
    })),

  clearMoodError: () =>
    set((state) => ({
      loading: { ...state.loading, error: null },
    })),

  // Sync actions
  markAsSynced: (id) =>
    set((state) => ({
      entries: state.entries.map((entry) =>
        entry.id === id
          ? {
              ...entry,
              is_synced: true,
              synced_at: new Date(),
            }
          : entry
      ),
      unsyncedEntries: state.unsyncedEntries.filter((entryId) => entryId !== id),
    })),

  markAsUnsynced: (id) =>
    set((state) => ({
      entries: state.entries.map((entry) =>
        entry.id === id ? { ...entry, is_synced: false } : entry
      ),
      unsyncedEntries: state.unsyncedEntries.includes(id)
        ? state.unsyncedEntries
        : [...state.unsyncedEntries, id],
    })),

  setLastSynced: (date) => set(() => ({ lastSyncedAt: date })),

  clearUnsyncedEntries: () => set(() => ({ unsyncedEntries: [] })),

  // Computed helpers
  getMoodEntryById: (id) => {
    return get().entries.find((entry) => entry.id === id);
  },

  getMoodEntriesByDateRange: (startDate, endDate) => {
    return get().entries.filter(
      (entry) =>
        entry.timestamp >= startDate && entry.timestamp <= endDate
    );
  },

  getAverageMood: (period) => {
    const now = new Date();
    let startDate: Date;

    switch (period) {
      case 'week':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      case 'year':
        startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
        break;
    }

    const entries = get().getMoodEntriesByDateRange(startDate, now);

    if (entries.length === 0) return 0;

    const sum = entries.reduce((acc, entry) => acc + entry.mood_level, 0);
    return sum / entries.length;
  },

  getMoodStreak: () => {
    const entries = get().entries;
    if (entries.length === 0) return 0;

    let streak = 0;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Check for consecutive days with mood entries
    for (let i = 0; i < entries.length; i++) {
      const entryDate = new Date(entries[i].timestamp);
      entryDate.setHours(0, 0, 0, 0);

      const daysDiff = Math.floor(
        (today.getTime() - entryDate.getTime()) / (24 * 60 * 60 * 1000)
      );

      if (daysDiff === streak) {
        streak++;
      } else if (daysDiff > streak) {
        break; // Gap found, streak ends
      }
    }

    return streak;
  },
});

/**
 * Selectors for optimized component subscriptions
 */
export const selectMoodEntries = (state: MoodSlice) => state.entries;
export const selectMoodTrends = (state: MoodSlice) => state.trends;
export const selectMoodFilters = (state: MoodSlice) => state.filters;
export const selectMoodLoading = (state: MoodSlice) => state.loading;
export const selectUnsyncedMoodCount = (state: MoodSlice) =>
  state.unsyncedEntries.length;
export const selectRecentMoodEntries = (state: MoodSlice, count: number = 10) =>
  state.entries.slice(0, count);
export const selectMoodAverageWeek = (state: MoodSlice) =>
  state.getAverageMood('week');
export const selectMoodStreak = (state: MoodSlice) => state.getMoodStreak();

/**
 * Filtered mood entries selector
 */
export const selectFilteredMoodEntries = (state: MoodSlice) => {
  const { entries, filters } = state;
  let filtered = [...entries];

  if (filters.startDate) {
    filtered = filtered.filter((entry) => entry.timestamp >= filters.startDate!);
  }

  if (filters.endDate) {
    filtered = filtered.filter((entry) => entry.timestamp <= filters.endDate!);
  }

  if (filters.minMoodLevel !== null) {
    filtered = filtered.filter(
      (entry) => entry.mood_level >= filters.minMoodLevel!
    );
  }

  if (filters.maxMoodLevel !== null) {
    filtered = filtered.filter(
      (entry) => entry.mood_level <= filters.maxMoodLevel!
    );
  }

  if (filters.activities.length > 0) {
    filtered = filtered.filter((entry) =>
      filters.activities.some((activity) => entry.activities.includes(activity))
    );
  }

  return filtered;
};
