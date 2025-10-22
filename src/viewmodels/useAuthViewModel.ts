/**
 * Auth ViewModel - User authentication and session management
 *
 * Manages user authentication, session state, preferences, and sync coordination.
 * Coordinates with Supabase Auth and SecureStorage for token management.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { useCallback, useMemo, useEffect } from 'react';
import { useAppStore } from '../stores';
import type {
  UserProfile,
  UserPreferences,
  LoginCredentials,
  SignupCredentials,
} from '../types';

/**
 * Auth ViewModel - Authentication and session management
 *
 * Usage:
 * ```typescript
 * const {
 *   user, isAuthenticated, preferences,
 *   login, logout, signup,
 *   updateProfile, updatePreferences,
 *   sessionInfo, syncStatus,
 *   isLoading
 * } = useAuthViewModel();
 * ```
 */
export const useAuthViewModel = () => {
  // ============================================================================
  // ZUSTAND STORE STATE
  // ============================================================================

  const user = useAppStore((state) => state.user);
  const isAuthenticated = useAppStore((state) => state.isAuthenticated);
  const isAnonymous = useAppStore((state) => state.isAnonymous);
  const preferences = useAppStore((state) => state.preferences);
  const session = useAppStore((state) => state.session);
  const sync = useAppStore((state) => state.sync);

  // Store actions
  const setUser = useAppStore((state) => state.setUser);
  const updateUserProfile = useAppStore((state) => state.updateUserProfile);
  const logout = useAppStore((state) => state.logout);
  const updatePreferences = useAppStore((state) => state.updatePreferences);
  const startSync = useAppStore((state) => state.startSync);
  const completeSync = useAppStore((state) => state.completeSync);

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /**
   * Session information
   */
  const sessionInfo = useMemo(() => {
    return {
      isActive: session.isActive,
      sessionStartedAt: session.sessionStartedAt,
      lastActiveAt: session.lastActiveAt,
      deviceId: session.deviceId,
      sessionDuration: session.sessionStartedAt
        ? Date.now() - session.sessionStartedAt.getTime()
        : 0,
    };
  }, [session]);

  /**
   * Sync status information
   */
  const syncStatus = useMemo(() => {
    return {
      isSyncing: sync.isSyncing,
      lastSyncedAt: sync.lastSyncedAt,
      pendingChanges: sync.pendingChanges,
      syncError: sync.syncError,
      hasUnsyncedChanges: sync.pendingChanges > 0,
    };
  }, [sync]);

  /**
   * User display information
   */
  const userDisplayInfo = useMemo(() => {
    if (!user) return null;

    return {
      displayName: user.display_name || user.email || 'User',
      initials: getInitials(user.display_name || user.email || 'U'),
      avatarUrl: user.avatar_url,
      email: user.email,
      isAnonymous,
    };
  }, [user, isAnonymous]);

  /**
   * Check if user session is active (last activity within 30 minutes)
   */
  const isSessionActive = useMemo(() => {
    if (!session.lastActiveAt) return false;

    const thirtyMinutesAgo = new Date();
    thirtyMinutesAgo.setMinutes(thirtyMinutesAgo.getMinutes() - 30);

    return new Date(session.lastActiveAt) > thirtyMinutesAgo;
  }, [session.lastActiveAt]);

  // ============================================================================
  // SESSION MANAGEMENT
  // ============================================================================

  /**
   * Update last activity timestamp (heartbeat)
   */
  const updateActivity = useCallback(() => {
    if (user) {
      updateUserProfile({ last_active_at: new Date() });
    }
  }, [user, updateUserProfile]);

  /**
   * Auto-refresh activity every 5 minutes
   */
  useEffect(() => {
    if (!isAuthenticated) return;

    const interval = setInterval(() => {
      updateActivity();
    }, 5 * 60 * 1000); // 5 minutes

    return () => clearInterval(interval);
  }, [isAuthenticated, updateActivity]);

  // ============================================================================
  // AUTHENTICATION OPERATIONS
  // ============================================================================

  /**
   * Login with email and password
   */
  const login = useCallback(
    async (credentials: LoginCredentials) => {
      try {
        // TODO: Call Supabase Auth
        // const { user, session } = await SupabaseAuth.signInWithPassword({
        //   email: credentials.email,
        //   password: credentials.password,
        // });

        const mockUser: UserProfile = {
          id: 'mock-user-id',
          email: credentials.email,
          display_name: credentials.email.split('@')[0],
          avatar_url: null,
          created_at: new Date(),
          last_active_at: new Date(),
        };

        // Update store
        setUser(mockUser);

        // TODO: Store tokens in Keychain
        // await Keychain.setGenericPassword('access_token', session.access_token);
        // await Keychain.setGenericPassword('refresh_token', session.refresh_token);

        return { user: mockUser, success: true };
      } catch (error) {
        throw error;
      }
    },
    [setUser]
  );

  /**
   * Sign up new user
   */
  const signup = useCallback(
    async (credentials: SignupCredentials) => {
      try {
        // TODO: Call Supabase Auth
        // const { user, session } = await SupabaseAuth.signUp({
        //   email: credentials.email,
        //   password: credentials.password,
        //   options: {
        //     data: {
        //       display_name: credentials.displayName,
        //     },
        //   },
        // });

        const mockUser: UserProfile = {
          id: 'mock-user-id',
          email: credentials.email,
          display_name: credentials.displayName || credentials.email.split('@')[0],
          avatar_url: null,
          created_at: new Date(),
          last_active_at: new Date(),
        };

        // Update store
        setUser(mockUser);

        // TODO: Store tokens in Keychain
        // await Keychain.setGenericPassword('access_token', session.access_token);

        return { user: mockUser, success: true };
      } catch (error) {
        throw error;
      }
    },
    [setUser]
  );

  /**
   * Login anonymously (guest mode)
   */
  const loginAnonymously = useCallback(async () => {
    try {
      // TODO: Call Supabase Auth anonymous login
      // const { user } = await SupabaseAuth.signInAnonymously();

      const mockUser: UserProfile = {
        id: `anon-${Date.now()}`,
        email: null,
        display_name: 'Guest',
        avatar_url: null,
        created_at: new Date(),
        last_active_at: new Date(),
      };

      setUser(mockUser);

      return { user: mockUser, success: true };
    } catch (error) {
      throw error;
    }
  }, [setUser]);

  /**
   * Logout user and clear session
   */
  const performLogout = useCallback(async () => {
    try {
      // TODO: Call Supabase Auth logout
      // await SupabaseAuth.signOut();

      // TODO: Clear tokens from Keychain
      // await Keychain.resetGenericPassword();

      // Clear store
      logout();

      return { success: true };
    } catch (error) {
      throw error;
    }
  }, [logout]);

  // ============================================================================
  // PROFILE MANAGEMENT
  // ============================================================================

  /**
   * Update user profile
   */
  const updateProfile = useCallback(
    async (updates: Partial<UserProfile>) => {
      if (!user) return;

      try {
        // Optimistic update
        updateUserProfile(updates);

        // TODO: Call Supabase to update profile
        // await SupabaseAuth.updateUser({
        //   data: updates,
        // });

        return { success: true };
      } catch (error) {
        // Rollback on error
        throw error;
      }
    },
    [user, updateUserProfile]
  );

  /**
   * Upload avatar image
   */
  const uploadAvatar = useCallback(
    async (imageUri: string) => {
      if (!user) return;

      try {
        // TODO: Upload to Supabase Storage
        // const { url } = await SupabaseStorage.upload(
        //   `avatars/${user.id}`,
        //   imageUri
        // );

        const mockUrl = imageUri;

        updateUserProfile({ avatar_url: mockUrl });

        return { url: mockUrl, success: true };
      } catch (error) {
        throw error;
      }
    },
    [user, updateUserProfile]
  );

  // ============================================================================
  // PREFERENCES MANAGEMENT
  // ============================================================================

  /**
   * Update user preferences
   */
  const updateUserPreferences = useCallback(
    async (updates: Partial<UserPreferences>) => {
      try {
        // Update store
        updatePreferences(updates);

        // TODO: Sync to Supabase
        // await UserPreferencesRepository.update(user?.id, updates);

        return { success: true };
      } catch (error) {
        throw error;
      }
    },
    [updatePreferences]
  );

  /**
   * Toggle dark mode
   */
  const toggleDarkMode = useCallback(() => {
    updatePreferences({
      theme: preferences.theme === 'dark' ? 'light' : 'dark',
    });
  }, [preferences.theme, updatePreferences]);

  /**
   * Update language preference
   */
  const updateLanguage = useCallback(
    (language: string) => {
      updatePreferences({ language });
    },
    [updatePreferences]
  );

  /**
   * Toggle notifications
   */
  const toggleNotifications = useCallback(
    (enabled: boolean) => {
      updatePreferences({
        notifications: {
          ...preferences.notifications,
          enabled,
        },
      });
    },
    [preferences.notifications, updatePreferences]
  );

  // ============================================================================
  // SYNC MANAGEMENT
  // ============================================================================

  /**
   * Trigger manual sync
   */
  const triggerSync = useCallback(async () => {
    try {
      startSync();

      // TODO: Call sync service
      // await SyncService.syncAll();

      completeSync(true);
    } catch (error) {
      completeSync(false, (error as Error).message);
      throw error;
    }
  }, [startSync, completeSync]);

  // ============================================================================
  // PASSWORD MANAGEMENT
  // ============================================================================

  /**
   * Change password
   */
  const changePassword = useCallback(
    async (currentPassword: string, newPassword: string) => {
      try {
        // TODO: Call Supabase Auth
        // await SupabaseAuth.updateUser({
        //   password: newPassword,
        // });

        return { success: true };
      } catch (error) {
        throw error;
      }
    },
    []
  );

  /**
   * Request password reset
   */
  const requestPasswordReset = useCallback(async (email: string) => {
    try {
      // TODO: Call Supabase Auth
      // await SupabaseAuth.resetPasswordForEmail(email);

      return { success: true };
    } catch (error) {
      throw error;
    }
  }, []);

  // ============================================================================
  // RETURN VIEWMODEL INTERFACE
  // ============================================================================

  return {
    // User state
    user,
    isAuthenticated,
    isAnonymous,
    userDisplayInfo,
    isSessionActive,

    // Authentication
    login,
    signup,
    loginAnonymously,
    logout: performLogout,

    // Profile management
    updateProfile,
    uploadAvatar,

    // Preferences
    preferences,
    updatePreferences: updateUserPreferences,
    toggleDarkMode,
    updateLanguage,
    toggleNotifications,

    // Session management
    sessionInfo,
    updateActivity,

    // Sync management
    syncStatus,
    triggerSync,

    // Password management
    changePassword,
    requestPasswordReset,

    // Loading state (derived from session state)
    isLoading: !session.isActive && isAuthenticated,
  };
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Get initials from display name or email
 */
function getInitials(name: string): string {
  const parts = name.split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return name.substring(0, 2).toUpperCase();
}
