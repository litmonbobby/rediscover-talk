/**
 * Breathing Slice - Breathing Exercises & Sessions
 *
 * Manages breathing exercise sessions and progress tracking.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';
import { BreathingSession } from '../../types/schemas';

export interface BreathingSlice {
  sessions: BreathingSession[];
  favoriteBreathingExercises: string[]; // Exercise IDs
  breathingStreak: number;
  unsyncedSessions: string[];
  activeSessionId: string | null;
  isLoading: boolean;
  error: string | null;

  addSession: (session: BreathingSession) => void;
  updateSession: (id: string, updates: Partial<BreathingSession>) => void;
  deleteSession: (id: string) => void;
  setActiveSession: (id: string | null) => void;
  toggleFavoriteBreathingExercise: (exerciseId: string) => void;
  setBreathingStreak: (streak: number) => void;
  setBreathingLoading: (isLoading: boolean) => void;
  setBreathingError: (error: string | null) => void;
  markSessionSynced: (id: string) => void;
  clearBreathingSessions: () => void;

  getSessionsByExercise: (exerciseId: string) => BreathingSession[];
  getRecentSessions: (count: number) => BreathingSession[];
}

export const createBreathingSlice: StateCreator<BreathingSlice> = (set, get) => ({
  sessions: [],
  favoriteBreathingExercises: [],
  breathingStreak: 0,
  unsyncedSessions: [],
  activeSessionId: null,
  isLoading: false,
  error: null,

  addSession: (session) =>
    set((state) => ({
      sessions: [session, ...state.sessions].sort(
        (a, b) => b.completion_date.getTime() - a.completion_date.getTime()
      ),
      unsyncedSessions: session.is_synced
        ? state.unsyncedSessions
        : [...state.unsyncedSessions, session.id],
    })),

  updateSession: (id, updates) =>
    set((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === id ? { ...s, ...updates, updated_at: new Date() } : s
      ),
    })),

  deleteSession: (id) =>
    set((state) => ({
      sessions: state.sessions.filter((s) => s.id !== id),
      unsyncedSessions: state.unsyncedSessions.filter((sId) => sId !== id),
    })),

  setActiveSession: (id) => set(() => ({ activeSessionId: id })),

  toggleFavoriteBreathingExercise: (exerciseId) =>
    set((state) => ({
      favoriteBreathingExercises: state.favoriteBreathingExercises.includes(exerciseId)
        ? state.favoriteBreathingExercises.filter((id) => id !== exerciseId)
        : [...state.favoriteBreathingExercises, exerciseId],
    })),

  setBreathingStreak: (streak) => set(() => ({ breathingStreak: streak })),
  setBreathingLoading: (isLoading) => set(() => ({ isLoading })),
  setBreathingError: (error) => set(() => ({ error })),

  markSessionSynced: (id) =>
    set((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === id ? { ...s, is_synced: true } : s
      ),
      unsyncedSessions: state.unsyncedSessions.filter((sId) => sId !== id),
    })),

  clearBreathingSessions: () =>
    set(() => ({
      sessions: [],
      favoriteBreathingExercises: [],
      breathingStreak: 0,
      unsyncedSessions: [],
      activeSessionId: null,
    })),

  getSessionsByExercise: (exerciseId) =>
    get().sessions.filter((s) => s.exercise_id === exerciseId),

  getRecentSessions: (count) => get().sessions.slice(0, count),
});
