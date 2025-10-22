/**
 * Prompts Slice - Daily Conversation Prompts
 *
 * Manages conversation prompts, user responses, and completion tracking.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';
import { ConversationPrompt, PromptResponse } from '../../types/schemas';

export interface PromptsSlice {
  todayPrompt: ConversationPrompt | null;
  responses: PromptResponse[];
  completionStreak: number;
  unsyncedResponses: string[];
  isLoading: boolean;
  error: string | null;

  setTodayPrompt: (prompt: ConversationPrompt | null) => void;
  addResponse: (response: PromptResponse) => void;
  updateResponse: (id: string, updates: Partial<PromptResponse>) => void;
  deleteResponse: (id: string) => void;
  setCompletionStreak: (streak: number) => void;
  setPromptsLoading: (isLoading: boolean) => void;
  setPromptsError: (error: string | null) => void;
  markResponseSynced: (id: string) => void;
  clearPromptResponses: () => void;

  getResponseById: (id: string) => PromptResponse | undefined;
  getRecentResponses: (count: number) => PromptResponse[];
}

export const createPromptsSlice: StateCreator<PromptsSlice> = (set, get) => ({
  todayPrompt: null,
  responses: [],
  completionStreak: 0,
  unsyncedResponses: [],
  isLoading: false,
  error: null,

  setTodayPrompt: (prompt) => set(() => ({ todayPrompt: prompt })),

  addResponse: (response) =>
    set((state) => ({
      responses: [response, ...state.responses].sort(
        (a, b) => b.created_at.getTime() - a.created_at.getTime()
      ),
      unsyncedResponses: response.is_synced
        ? state.unsyncedResponses
        : [...state.unsyncedResponses, response.id],
    })),

  updateResponse: (id, updates) =>
    set((state) => ({
      responses: state.responses.map((r) =>
        r.id === id ? { ...r, ...updates, updated_at: new Date() } : r
      ),
    })),

  deleteResponse: (id) =>
    set((state) => ({
      responses: state.responses.filter((r) => r.id !== id),
      unsyncedResponses: state.unsyncedResponses.filter((rId) => rId !== id),
    })),

  setCompletionStreak: (streak) => set(() => ({ completionStreak: streak })),
  setPromptsLoading: (isLoading) => set(() => ({ isLoading })),
  setPromptsError: (error) => set(() => ({ error })),

  markResponseSynced: (id) =>
    set((state) => ({
      responses: state.responses.map((r) =>
        r.id === id ? { ...r, is_synced: true } : r
      ),
      unsyncedResponses: state.unsyncedResponses.filter((rId) => rId !== id),
    })),

  clearPromptResponses: () =>
    set(() => ({
      responses: [],
      completionStreak: 0,
      unsyncedResponses: [],
    })),

  getResponseById: (id) => get().responses.find((r) => r.id === id),
  getRecentResponses: (count) => get().responses.slice(0, count),
});
