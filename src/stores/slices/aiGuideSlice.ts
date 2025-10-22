/**
 * AIGuide Slice - AI Conversation Support
 *
 * Manages AI conversation metadata and typing indicators.
 * Full conversation messages stored in SecureStorage.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';

export interface AIGuideSlice {
  conversationCount: number;
  lastConversationAt: Date | null;
  isTyping: boolean;
  isLoading: boolean;
  error: string | null;
  activeConversationId: string | null;
  messageCount: number;

  setConversationCount: (count: number) => void;
  incrementConversationCount: () => void;
  setLastConversationAt: (date: Date) => void;
  setIsTyping: (isTyping: boolean) => void;
  setAIGuideLoading: (isLoading: boolean) => void;
  setAIGuideError: (error: string | null) => void;
  setActiveConversation: (id: string | null) => void;
  setMessageCount: (count: number) => void;
  incrementMessageCount: () => void;
  clearAIConversations: () => void;
}

export const createAIGuideSlice: StateCreator<AIGuideSlice> = (set) => ({
  conversationCount: 0,
  lastConversationAt: null,
  isTyping: false,
  isLoading: false,
  error: null,
  activeConversationId: null,
  messageCount: 0,

  setConversationCount: (count) => set(() => ({ conversationCount: count })),
  incrementConversationCount: () =>
    set((state) => ({ conversationCount: state.conversationCount + 1 })),

  setLastConversationAt: (date) => set(() => ({ lastConversationAt: date })),
  setIsTyping: (isTyping) => set(() => ({ isTyping })),
  setAIGuideLoading: (isLoading) => set(() => ({ isLoading })),
  setAIGuideError: (error) => set(() => ({ error })),
  setActiveConversation: (id) => set(() => ({ activeConversationId: id })),
  setMessageCount: (count) => set(() => ({ messageCount: count })),
  incrementMessageCount: () =>
    set((state) => ({ messageCount: state.messageCount + 1 })),

  clearAIConversations: () =>
    set(() => ({
      conversationCount: 0,
      lastConversationAt: null,
      isTyping: false,
      activeConversationId: null,
      messageCount: 0,
    })),
});
