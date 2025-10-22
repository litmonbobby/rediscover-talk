/**
 * Wellness ViewModel - Mood, Breathing, and Exercise tracking
 *
 * Aggregates state from MoodSlice, BreathingSlice, and ExercisesSlice
 * to provide unified wellness tracking interface for UI components.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { useCallback, useMemo } from 'react';
import { useAppStore } from '../stores';
import {
  selectMoodTrends,
  selectActivityCorrelations,
  selectFilteredMoodEntries,
} from '../stores/selectors/moodSelectors';
import { selectBreathingStats } from '../stores/selectors/breathingSelectors';
import { selectExerciseProgress } from '../stores/selectors/exercisesSelectors';
import type {
  MoodEntry,
  CreateMoodEntryInput,
  MoodFilters,
  BreathingSession,
  CreateBreathingSessionInput,
  ExerciseCompletion,
  CreateExerciseCompletionInput,
} from '../types';

/**
 * Wellness ViewModel - Unified interface for wellness tracking
 *
 * Usage:
 * ```typescript
 * const {
 *   // Mood tracking
 *   moodEntries, trends, createMoodEntry,
 *   // Breathing exercises
 *   breathingSessions, breathingStats, startBreathingSession,
 *   // Family exercises
 *   exerciseCompletions, exerciseProgress, completeExercise,
 *   // Loading states
 *   isLoading
 * } = useWellnessViewModel();
 * ```
 */
export const useWellnessViewModel = () => {
  // ============================================================================
  // MOOD TRACKING STATE & SELECTORS
  // ============================================================================

  const moodEntries = useAppStore(selectFilteredMoodEntries);
  const trends = useAppStore(selectMoodTrends);
  const activityCorrelations = useAppStore(selectActivityCorrelations);
  const moodFilters = useAppStore((state) => state.filters);
  const moodLoading = useAppStore((state) => state.loading);

  const addMoodEntry = useAppStore((state) => state.addMoodEntry);
  const updateMoodEntry = useAppStore((state) => state.updateMoodEntry);
  const deleteMoodEntry = useAppStore((state) => state.deleteMoodEntry);
  const setMoodFilters = useAppStore((state) => state.setMoodFilters);
  const getAverageMood = useAppStore((state) => state.getAverageMood);
  const getMoodStreak = useAppStore((state) => state.getMoodStreak);

  // ============================================================================
  // BREATHING EXERCISES STATE & SELECTORS
  // ============================================================================

  const breathingSessions = useAppStore((state) => state.sessions);
  const breathingStats = useAppStore(selectBreathingStats);
  const activeBreathingSession = useAppStore((state) => state.activeSessionId);
  const breathingStreak = useAppStore((state) => state.breathingStreak);

  const addBreathingSession = useAppStore((state) => state.addSession);
  const setActiveBreathingSession = useAppStore((state) => state.setActiveSession);
  const toggleFavoriteBreathing = useAppStore((state) => state.toggleFavoriteBreathingExercise);

  // ============================================================================
  // FAMILY EXERCISES STATE & SELECTORS
  // ============================================================================

  const exerciseCompletions = useAppStore((state) => state.completions);
  const exerciseProgress = useAppStore(selectExerciseProgress);
  const exerciseStreak = useAppStore((state) => state.exerciseStreak);
  const favoriteExercises = useAppStore((state) => state.favoriteExercises);

  const addExerciseCompletion = useAppStore((state) => state.addCompletion);
  const toggleFavoriteExercise = useAppStore((state) => state.toggleFavoriteExercise);

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /**
   * Overall wellness summary combining all wellness metrics
   */
  const wellnessSummary = useMemo(() => {
    const weekAverage = getAverageMood('week');
    const moodStreak = getMoodStreak();

    return {
      // Mood metrics
      weekAverageMood: weekAverage,
      moodStreak,
      totalMoodEntries: moodEntries.length,

      // Breathing metrics
      totalBreathingSessions: breathingStats.totalSessions,
      averageMoodImprovement: breathingStats.averageMoodImprovement,
      averageAnxietyReduction: breathingStats.averageAnxietyReduction,
      breathingStreak,

      // Exercise metrics
      totalExercises: exerciseProgress.totalCompletions,
      uniqueExercises: exerciseProgress.uniqueExercises,
      averageEnjoyment: exerciseProgress.averageEnjoyment,
      exerciseStreak,

      // Overall wellness score (0-100)
      wellnessScore: calculateWellnessScore(
        weekAverage,
        moodStreak,
        breathingStats.totalSessions,
        exerciseProgress.totalCompletions
      ),
    };
  }, [
    moodEntries.length,
    breathingStats,
    exerciseProgress,
    breathingStreak,
    exerciseStreak,
    getAverageMood,
    getMoodStreak,
  ]);

  /**
   * Loading state aggregation
   */
  const isLoading = useMemo(() => {
    return (
      moodLoading.entries ||
      moodLoading.trends ||
      moodLoading.analytics
    );
  }, [moodLoading]);

  // ============================================================================
  // MOOD TRACKING ACTIONS
  // ============================================================================

  /**
   * Create new mood entry with optimistic update
   */
  const createMoodEntry = useCallback(
    async (input: CreateMoodEntryInput) => {
      const optimisticEntry: MoodEntry = {
        id: `temp-${Date.now()}`,
        user_id: input.user_id,
        mood_level: input.mood_level,
        activities: input.activities || [],
        notes: input.notes || '',
        timestamp: new Date(),
        is_synced: false,
      };

      // Optimistic update
      addMoodEntry(optimisticEntry);

      try {
        // TODO: Call MoodRepository.create(input)
        // const saved = await MoodRepository.create(input);
        // updateMoodEntry(optimisticEntry.id, saved);
      } catch (error) {
        // Rollback on failure
        deleteMoodEntry(optimisticEntry.id);
        throw error;
      }
    },
    [addMoodEntry, updateMoodEntry, deleteMoodEntry]
  );

  /**
   * Update existing mood entry
   */
  const updateMood = useCallback(
    async (id: string, updates: Partial<MoodEntry>) => {
      updateMoodEntry(id, updates);

      try {
        // TODO: Call MoodRepository.update(id, updates)
      } catch (error) {
        // TODO: Rollback logic
        throw error;
      }
    },
    [updateMoodEntry]
  );

  /**
   * Delete mood entry
   */
  const deleteMood = useCallback(
    async (id: string) => {
      deleteMoodEntry(id);

      try {
        // TODO: Call MoodRepository.delete(id)
      } catch (error) {
        // TODO: Rollback logic
        throw error;
      }
    },
    [deleteMoodEntry]
  );

  /**
   * Apply mood filters for list view
   */
  const applyMoodFilters = useCallback(
    (filters: Partial<MoodFilters>) => {
      setMoodFilters(filters);
    },
    [setMoodFilters]
  );

  // ============================================================================
  // BREATHING EXERCISE ACTIONS
  // ============================================================================

  /**
   * Start new breathing session
   */
  const startBreathingSession = useCallback(
    async (input: CreateBreathingSessionInput) => {
      const session: BreathingSession = {
        id: `temp-${Date.now()}`,
        user_id: input.user_id,
        exercise_id: input.exercise_id,
        duration_seconds: input.duration_seconds,
        mood_before: input.mood_before,
        mood_after: input.mood_after,
        anxiety_before: input.anxiety_before,
        anxiety_after: input.anxiety_after,
        completed_at: new Date(),
        is_synced: false,
      };

      addBreathingSession(session);
      setActiveBreathingSession(session.id);

      try {
        // TODO: Call BreathingRepository.create(input)
      } catch (error) {
        throw error;
      }
    },
    [addBreathingSession, setActiveBreathingSession]
  );

  /**
   * Complete active breathing session
   */
  const completeBreathingSession = useCallback(
    async (moodAfter: number, anxietyAfter: number) => {
      if (!activeBreathingSession) return;

      updateMoodEntry(activeBreathingSession, {
        mood_after: moodAfter,
        anxiety_after: anxietyAfter,
        completed_at: new Date(),
      } as any);

      setActiveBreathingSession(null);

      try {
        // TODO: Update in repository
      } catch (error) {
        throw error;
      }
    },
    [activeBreathingSession, updateMoodEntry, setActiveBreathingSession]
  );

  // ============================================================================
  // FAMILY EXERCISE ACTIONS
  // ============================================================================

  /**
   * Complete family exercise
   */
  const completeExercise = useCallback(
    async (input: CreateExerciseCompletionInput) => {
      const completion: ExerciseCompletion = {
        id: `temp-${Date.now()}`,
        user_id: input.user_id,
        exercise_id: input.exercise_id,
        participants: input.participants,
        enjoyment_rating: input.enjoyment_rating,
        notes: input.notes || '',
        completed_at: new Date(),
        is_synced: false,
      };

      addExerciseCompletion(completion);

      try {
        // TODO: Call ExercisesRepository.create(input)
      } catch (error) {
        throw error;
      }
    },
    [addExerciseCompletion]
  );

  // ============================================================================
  // RETURN VIEWMODEL INTERFACE
  // ============================================================================

  return {
    // Mood tracking
    moodEntries,
    trends,
    activityCorrelations,
    moodFilters,
    createMoodEntry,
    updateMood,
    deleteMood,
    applyMoodFilters,
    getAverageMood,
    getMoodStreak: getMoodStreak(),

    // Breathing exercises
    breathingSessions,
    breathingStats,
    activeBreathingSession,
    breathingStreak,
    startBreathingSession,
    completeBreathingSession,
    toggleFavoriteBreathing,

    // Family exercises
    exerciseCompletions,
    exerciseProgress,
    exerciseStreak,
    favoriteExercises,
    completeExercise,
    toggleFavoriteExercise,

    // Wellness summary
    wellnessSummary,

    // Loading states
    isLoading,
  };
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Calculate overall wellness score (0-100)
 */
function calculateWellnessScore(
  averageMood: number,
  moodStreak: number,
  breathingSessions: number,
  exerciseCompletions: number
): number {
  // Weighted scoring
  const moodScore = (averageMood / 5) * 40; // 40% weight
  const streakScore = Math.min((moodStreak / 30) * 20, 20); // 20% weight (cap at 30 days)
  const breathingScore = Math.min((breathingSessions / 10) * 20, 20); // 20% weight
  const exerciseScore = Math.min((exerciseCompletions / 10) * 20, 20); // 20% weight

  return Math.round(moodScore + streakScore + breathingScore + exerciseScore);
}
