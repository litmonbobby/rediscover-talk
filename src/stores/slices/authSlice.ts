/**
 * Auth Slice - User Session & Authentication State
 *
 * Manages user authentication, profile data, and app preferences.
 * Implements offline-first auth with token refresh and biometric support.
 *
 * Security:
 * - Tokens stored in Keychain (not Zustand)
 * - Only user profile and session state in store
 * - Biometric authentication metadata tracked
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';
import { UserProfile } from '../../types/schemas';

/**
 * User preferences configuration
 */
export interface UserPreferences {
  notifications_enabled: boolean;
  daily_reminder_time: string | null; // HH:MM format
  theme: 'light' | 'dark' | 'system';
  language: 'en' | 'es' | 'fr';
  biometric_enabled: boolean;
  auto_sync: boolean;
  analytics_enabled: boolean;
}

/**
 * Session state metadata
 */
export interface SessionState {
  isLoading: boolean;
  lastActiveAt: Date | null;
  sessionStartedAt: Date | null;
  error: string | null;
}

/**
 * Sync state for offline-first operations
 */
export interface SyncState {
  isSyncing: boolean;
  lastSyncedAt: Date | null;
  syncError: string | null;
  pendingChanges: number;
}

/**
 * Auth Slice Interface
 */
export interface AuthSlice {
  // User state
  user: UserProfile | null;
  isAuthenticated: boolean;
  isAnonymous: boolean;
  preferences: UserPreferences;

  // Session state
  session: SessionState;

  // Sync state
  sync: SyncState;

  // Actions: Authentication
  setUser: (user: UserProfile) => void;
  updateUserProfile: (updates: Partial<UserProfile>) => void;
  logout: () => void;
  setAnonymousMode: (isAnonymous: boolean) => void;

  // Actions: Preferences
  updatePreferences: (updates: Partial<UserPreferences>) => void;
  toggleNotifications: () => void;
  setTheme: (theme: UserPreferences['theme']) => void;
  setLanguage: (language: UserPreferences['language']) => void;
  enableBiometric: (enabled: boolean) => void;

  // Actions: Session management
  startSession: () => void;
  endSession: () => void;
  updateLastActive: () => void;
  setAuthError: (error: string | null) => void;
  clearAuthError: () => void;

  // Actions: Sync management
  startSync: () => void;
  completeSync: (success: boolean, error?: string) => void;
  incrementPendingChanges: () => void;
  decrementPendingChanges: () => void;
  clearPendingChanges: () => void;
}

/**
 * Default preferences
 */
const defaultPreferences: UserPreferences = {
  notifications_enabled: true,
  daily_reminder_time: '09:00',
  theme: 'system',
  language: 'en',
  biometric_enabled: false,
  auto_sync: true,
  analytics_enabled: true,
};

/**
 * Default session state
 */
const defaultSession: SessionState = {
  isLoading: false,
  lastActiveAt: null,
  sessionStartedAt: null,
  error: null,
};

/**
 * Default sync state
 */
const defaultSync: SyncState = {
  isSyncing: false,
  lastSyncedAt: null,
  syncError: null,
  pendingChanges: 0,
};

/**
 * Create Auth Slice
 */
export const createAuthSlice: StateCreator<AuthSlice> = (set, get) => ({
  // Initial state
  user: null,
  isAuthenticated: false,
  isAnonymous: false,
  preferences: defaultPreferences,
  session: defaultSession,
  sync: defaultSync,

  // Authentication actions
  setUser: (user) =>
    set(() => ({
      user,
      isAuthenticated: true,
      isAnonymous: false,
      session: {
        ...defaultSession,
        sessionStartedAt: new Date(),
        lastActiveAt: new Date(),
      },
    })),

  updateUserProfile: (updates) =>
    set((state) => ({
      user: state.user ? { ...state.user, ...updates } : null,
    })),

  logout: () =>
    set(() => ({
      user: null,
      isAuthenticated: false,
      isAnonymous: false,
      preferences: defaultPreferences,
      session: defaultSession,
      sync: defaultSync,
    })),

  setAnonymousMode: (isAnonymous) =>
    set((state) => ({
      isAnonymous,
      isAuthenticated: isAnonymous, // Anonymous users are "authenticated" without account
      user: isAnonymous
        ? {
            id: `anon-${Date.now()}`,
            email: null,
            display_name: 'Anonymous User',
            avatar_url: null,
            preferences: state.preferences,
            is_anonymous: true,
            created_at: new Date(),
            updated_at: new Date(),
            synced_at: null,
            is_synced: false,
          }
        : null,
      session: {
        ...state.session,
        sessionStartedAt: isAnonymous ? new Date() : null,
        lastActiveAt: isAnonymous ? new Date() : null,
      },
    })),

  // Preferences actions
  updatePreferences: (updates) =>
    set((state) => ({
      preferences: { ...state.preferences, ...updates },
      user: state.user
        ? {
            ...state.user,
            preferences: { ...state.user.preferences, ...updates },
          }
        : null,
    })),

  toggleNotifications: () =>
    set((state) => ({
      preferences: {
        ...state.preferences,
        notifications_enabled: !state.preferences.notifications_enabled,
      },
    })),

  setTheme: (theme) =>
    set((state) => ({
      preferences: { ...state.preferences, theme },
    })),

  setLanguage: (language) =>
    set((state) => ({
      preferences: { ...state.preferences, language },
    })),

  enableBiometric: (enabled) =>
    set((state) => ({
      preferences: { ...state.preferences, biometric_enabled: enabled },
    })),

  // Session actions
  startSession: () =>
    set((state) => ({
      session: {
        ...state.session,
        sessionStartedAt: new Date(),
        lastActiveAt: new Date(),
        error: null,
      },
    })),

  endSession: () =>
    set((state) => ({
      session: {
        ...state.session,
        sessionStartedAt: null,
        lastActiveAt: null,
      },
    })),

  updateLastActive: () =>
    set((state) => ({
      session: {
        ...state.session,
        lastActiveAt: new Date(),
      },
    })),

  setAuthError: (error) =>
    set((state) => ({
      session: { ...state.session, error },
    })),

  clearAuthError: () =>
    set((state) => ({
      session: { ...state.session, error: null },
    })),

  // Sync actions
  startSync: () =>
    set((state) => ({
      sync: {
        ...state.sync,
        isSyncing: true,
        syncError: null,
      },
    })),

  completeSync: (success, error) =>
    set((state) => ({
      sync: {
        ...state.sync,
        isSyncing: false,
        lastSyncedAt: success ? new Date() : state.sync.lastSyncedAt,
        syncError: error ?? null,
        pendingChanges: success ? 0 : state.sync.pendingChanges,
      },
    })),

  incrementPendingChanges: () =>
    set((state) => ({
      sync: {
        ...state.sync,
        pendingChanges: state.sync.pendingChanges + 1,
      },
    })),

  decrementPendingChanges: () =>
    set((state) => ({
      sync: {
        ...state.sync,
        pendingChanges: Math.max(0, state.sync.pendingChanges - 1),
      },
    })),

  clearPendingChanges: () =>
    set((state) => ({
      sync: { ...state.sync, pendingChanges: 0 },
    })),
});

/**
 * Selectors for optimized component subscriptions
 */
export const selectIsAuthenticated = (state: AuthSlice) => state.isAuthenticated;
export const selectUser = (state: AuthSlice) => state.user;
export const selectPreferences = (state: AuthSlice) => state.preferences;
export const selectTheme = (state: AuthSlice) => state.preferences.theme;
export const selectLanguage = (state: AuthSlice) => state.preferences.language;
export const selectSyncStatus = (state: AuthSlice) => state.sync;
export const selectSessionActive = (state: AuthSlice) =>
  state.session.sessionStartedAt !== null;
export const selectHasPendingChanges = (state: AuthSlice) =>
  state.sync.pendingChanges > 0;
