/**
 * Exercises Slice - Family Exercises & Progress Tracking
 *
 * Manages family exercise completions and progress metrics.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';
import { ExerciseCompletion } from '../../types/schemas';

export interface ExercisesSlice {
  completions: ExerciseCompletion[];
  favoriteExercises: string[]; // Exercise IDs
  exerciseStreak: number;
  unsyncedCompletions: string[];
  isLoading: boolean;
  error: string | null;

  addCompletion: (completion: ExerciseCompletion) => void;
  updateCompletion: (id: string, updates: Partial<ExerciseCompletion>) => void;
  deleteCompletion: (id: string) => void;
  toggleFavoriteExercise: (exerciseId: string) => void;
  setExerciseStreak: (streak: number) => void;
  setExercisesLoading: (isLoading: boolean) => void;
  setExercisesError: (error: string | null) => void;
  markCompletionSynced: (id: string) => void;
  clearExerciseCompletions: () => void;

  getCompletionsByExercise: (exerciseId: string) => ExerciseCompletion[];
  getRecentCompletions: (count: number) => ExerciseCompletion[];
}

export const createExercisesSlice: StateCreator<ExercisesSlice> = (set, get) => ({
  completions: [],
  favoriteExercises: [],
  exerciseStreak: 0,
  unsyncedCompletions: [],
  isLoading: false,
  error: null,

  addCompletion: (completion) =>
    set((state) => ({
      completions: [completion, ...state.completions].sort(
        (a, b) => b.completion_date.getTime() - a.completion_date.getTime()
      ),
      unsyncedCompletions: completion.is_synced
        ? state.unsyncedCompletions
        : [...state.unsyncedCompletions, completion.id],
    })),

  updateCompletion: (id, updates) =>
    set((state) => ({
      completions: state.completions.map((c) =>
        c.id === id ? { ...c, ...updates, updated_at: new Date() } : c
      ),
    })),

  deleteCompletion: (id) =>
    set((state) => ({
      completions: state.completions.filter((c) => c.id !== id),
      unsyncedCompletions: state.unsyncedCompletions.filter((cId) => cId !== id),
    })),

  toggleFavoriteExercise: (exerciseId) =>
    set((state) => ({
      favoriteExercises: state.favoriteExercises.includes(exerciseId)
        ? state.favoriteExercises.filter((id) => id !== exerciseId)
        : [...state.favoriteExercises, exerciseId],
    })),

  setExerciseStreak: (streak) => set(() => ({ exerciseStreak: streak })),
  setExercisesLoading: (isLoading) => set(() => ({ isLoading })),
  setExercisesError: (error) => set(() => ({ error })),

  markCompletionSynced: (id) =>
    set((state) => ({
      completions: state.completions.map((c) =>
        c.id === id ? { ...c, is_synced: true } : c
      ),
      unsyncedCompletions: state.unsyncedCompletions.filter((cId) => cId !== id),
    })),

  clearExerciseCompletions: () =>
    set(() => ({
      completions: [],
      favoriteExercises: [],
      exerciseStreak: 0,
      unsyncedCompletions: [],
    })),

  getCompletionsByExercise: (exerciseId) =>
    get().completions.filter((c) => c.exercise_id === exerciseId),

  getRecentCompletions: (count) => get().completions.slice(0, count),
});
