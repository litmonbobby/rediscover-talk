/**
 * Crisis ViewModel - Emergency crisis plan with secure access
 *
 * Manages crisis plan metadata and coordinates biometric authentication
 * for accessing encrypted crisis plan content from SecureStorage.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { useCallback, useMemo, useState } from 'react';
import { useAppStore } from '../stores';
import type { CrisisPlan, CreateCrisisPlanInput, EmergencyContact } from '../types';

/**
 * Crisis ViewModel - Secure crisis plan management
 *
 * Usage:
 * ```typescript
 * const {
 *   hasCrisisPlan, crisisPlan, emergencyContacts,
 *   createCrisisPlan, updateCrisisPlan, deleteCrisisPlan,
 *   getCrisisPlanContent, markAsReviewed,
 *   requestBiometricAuth, isAuthenticated,
 *   isLoading
 * } = useCrisisViewModel();
 * ```
 */
export const useCrisisViewModel = () => {
  // ============================================================================
  // ZUSTAND STORE STATE
  // ============================================================================

  const hasCrisisPlan = useAppStore((state) => state.hasCrisisPlan);
  const lastReviewedAt = useAppStore((state) => state.lastReviewedAt);
  const emergencyContactCount = useAppStore((state) => state.emergencyContactCount);
  const professionalContactCount = useAppStore((state) => state.professionalContactCount);

  const setHasCrisisPlan = useAppStore((state) => state.setHasCrisisPlan);
  const setLastReviewed = useAppStore((state) => state.setLastReviewed);
  const updateEmergencyContactCount = useAppStore(
    (state) => state.updateEmergencyContactCount
  );
  const updateProfessionalContactCount = useAppStore(
    (state) => state.updateProfessionalContactCount
  );

  // ============================================================================
  // LOCAL STATE FOR SECURITY
  // ============================================================================

  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [decryptedPlan, setDecryptedPlan] = useState<CrisisPlan | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // Session timeout (5 minutes of inactivity)
  const [lastActivity, setLastActivity] = useState<Date>(new Date());

  // ============================================================================
  // COMPUTED PROPERTIES
  // ============================================================================

  /**
   * Check if crisis plan needs review (every 90 days)
   */
  const needsReview = useMemo(() => {
    if (!lastReviewedAt) return true;

    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    return new Date(lastReviewedAt) < ninetyDaysAgo;
  }, [lastReviewedAt]);

  /**
   * Days since last review
   */
  const daysSinceReview = useMemo(() => {
    if (!lastReviewedAt) return null;

    const now = new Date();
    const reviewed = new Date(lastReviewedAt);
    const diffMs = now.getTime() - reviewed.getTime();
    return Math.floor(diffMs / (1000 * 60 * 60 * 24));
  }, [lastReviewedAt]);

  /**
   * Check if session is expired (5 minutes)
   */
  const isSessionExpired = useMemo(() => {
    const fiveMinutesAgo = new Date();
    fiveMinutesAgo.setMinutes(fiveMinutesAgo.getMinutes() - 5);
    return lastActivity < fiveMinutesAgo;
  }, [lastActivity]);

  /**
   * Crisis plan summary
   */
  const crisisPlanSummary = useMemo(() => {
    return {
      hasPlan: hasCrisisPlan,
      emergencyContacts: emergencyContactCount,
      professionalContacts: professionalContactCount,
      totalContacts: emergencyContactCount + professionalContactCount,
      needsReview,
      daysSinceReview,
      lastReviewedAt,
    };
  }, [
    hasCrisisPlan,
    emergencyContactCount,
    professionalContactCount,
    needsReview,
    daysSinceReview,
    lastReviewedAt,
  ]);

  // ============================================================================
  // BIOMETRIC AUTHENTICATION
  // ============================================================================

  /**
   * Request biometric authentication (Face ID / Touch ID / Fingerprint)
   */
  const requestBiometricAuth = useCallback(async () => {
    try {
      setIsLoading(true);
      setAuthError(null);

      // TODO: Implement biometric authentication
      // const result = await BiometricAuth.authenticate({
      //   promptMessage: 'Authenticate to access crisis plan',
      //   fallbackLabel: 'Use PIN',
      // });

      const result = { success: true }; // Placeholder

      if (result.success) {
        setIsAuthenticated(true);
        setLastActivity(new Date());
        return true;
      } else {
        setAuthError('Authentication failed');
        return false;
      }
    } catch (error) {
      setAuthError((error as Error).message);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, []);

  /**
   * Clear authentication (lock crisis plan)
   */
  const clearAuth = useCallback(() => {
    setIsAuthenticated(false);
    setDecryptedPlan(null);
    setAuthError(null);
  }, []);

  /**
   * Refresh session activity timestamp
   */
  const refreshActivity = useCallback(() => {
    setLastActivity(new Date());
  }, []);

  /**
   * Check if re-authentication is needed
   */
  const checkAuth = useCallback(async () => {
    if (isSessionExpired) {
      clearAuth();
      return await requestBiometricAuth();
    }
    refreshActivity();
    return isAuthenticated;
  }, [
    isSessionExpired,
    isAuthenticated,
    clearAuth,
    requestBiometricAuth,
    refreshActivity,
  ]);

  // ============================================================================
  // CRISIS PLAN CRUD OPERATIONS
  // ============================================================================

  /**
   * Create new crisis plan with encryption
   */
  const createCrisisPlan = useCallback(
    async (input: CreateCrisisPlanInput) => {
      try {
        setIsLoading(true);

        // Ensure authenticated
        const authenticated = await checkAuth();
        if (!authenticated) {
          throw new Error('Authentication required');
        }

        const plan: CrisisPlan = {
          id: `plan-${Date.now()}`,
          user_id: input.user_id,
          warning_signs: input.warning_signs,
          coping_strategies: input.coping_strategies,
          emergency_contacts: input.emergency_contacts,
          professional_contacts: input.professional_contacts,
          safe_environment: input.safe_environment,
          emergency_services: input.emergency_services || {
            crisis_hotline: '988',
            emergency: '911',
          },
          created_at: new Date(),
          updated_at: new Date(),
        };

        // TODO: Encrypt and store in SecureStorage
        // const encrypted = await encryptCrisisPlan(plan);
        // await SecureStorage.setItem('crisis_plan', encrypted);

        // Update store metadata
        setHasCrisisPlan(true);
        setLastReviewed(new Date());
        updateEmergencyContactCount(plan.emergency_contacts.length);
        updateProfessionalContactCount(plan.professional_contacts.length);

        setDecryptedPlan(plan);

        // TODO: Sync metadata to Supabase (not encrypted content)
        // await CrisisRepository.createMetadata(userId, plan.id);

        return plan;
      } catch (error) {
        throw error;
      } finally {
        setIsLoading(false);
      }
    },
    [
      checkAuth,
      setHasCrisisPlan,
      setLastReviewed,
      updateEmergencyContactCount,
      updateProfessionalContactCount,
    ]
  );

  /**
   * Update existing crisis plan
   */
  const updateCrisisPlan = useCallback(
    async (updates: Partial<CrisisPlan>) => {
      try {
        setIsLoading(true);

        // Ensure authenticated
        const authenticated = await checkAuth();
        if (!authenticated) {
          throw new Error('Authentication required');
        }

        if (!decryptedPlan) {
          throw new Error('No crisis plan loaded');
        }

        const updatedPlan: CrisisPlan = {
          ...decryptedPlan,
          ...updates,
          updated_at: new Date(),
        };

        // TODO: Re-encrypt and update SecureStorage
        // const encrypted = await encryptCrisisPlan(updatedPlan);
        // await SecureStorage.setItem('crisis_plan', encrypted);

        // Update store metadata
        if (updates.emergency_contacts) {
          updateEmergencyContactCount(updates.emergency_contacts.length);
        }
        if (updates.professional_contacts) {
          updateProfessionalContactCount(updates.professional_contacts.length);
        }

        setDecryptedPlan(updatedPlan);

        // TODO: Sync metadata to Supabase
        // await CrisisRepository.updateMetadata(updatedPlan.user_id, updatedPlan.id);

        return updatedPlan;
      } catch (error) {
        throw error;
      } finally {
        setIsLoading(false);
      }
    },
    [
      checkAuth,
      decryptedPlan,
      updateEmergencyContactCount,
      updateProfessionalContactCount,
    ]
  );

  /**
   * Delete crisis plan
   */
  const deleteCrisisPlan = useCallback(async () => {
    try {
      setIsLoading(true);

      // Ensure authenticated
      const authenticated = await checkAuth();
      if (!authenticated) {
        throw new Error('Authentication required');
      }

      // TODO: Delete from SecureStorage
      // await SecureStorage.removeItem('crisis_plan');

      // Update store
      setHasCrisisPlan(false);
      setLastReviewed(null);
      updateEmergencyContactCount(0);
      updateProfessionalContactCount(0);

      setDecryptedPlan(null);

      // TODO: Delete from Supabase
      // await CrisisRepository.delete(userId);
    } catch (error) {
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [
    checkAuth,
    setHasCrisisPlan,
    setLastReviewed,
    updateEmergencyContactCount,
    updateProfessionalContactCount,
  ]);

  // ============================================================================
  // CONTENT RETRIEVAL
  // ============================================================================

  /**
   * Get decrypted crisis plan content
   */
  const getCrisisPlanContent = useCallback(async (): Promise<CrisisPlan | null> => {
    try {
      setIsLoading(true);

      // Ensure authenticated
      const authenticated = await checkAuth();
      if (!authenticated) {
        return null;
      }

      // Return cached if available
      if (decryptedPlan) {
        refreshActivity();
        return decryptedPlan;
      }

      // TODO: Retrieve and decrypt from SecureStorage
      // const encrypted = await SecureStorage.getItem('crisis_plan');
      // const plan = await decryptCrisisPlan(encrypted);

      const plan = null; // Placeholder

      setDecryptedPlan(plan);
      return plan;
    } catch (error) {
      throw error;
    } finally {
      setIsLoading(false);
    }
  }, [checkAuth, decryptedPlan, refreshActivity]);

  /**
   * Mark crisis plan as reviewed
   */
  const markAsReviewed = useCallback(() => {
    const now = new Date();
    setLastReviewed(now);
    refreshActivity();

    // TODO: Sync to Supabase
    // await CrisisRepository.updateLastReviewed(userId, now);
  }, [setLastReviewed, refreshActivity]);

  // ============================================================================
  // EMERGENCY ACTIONS
  // ============================================================================

  /**
   * Get emergency contact (no auth required for emergency access)
   */
  const getEmergencyContact = useCallback(
    (index: number): EmergencyContact | null => {
      if (!decryptedPlan) return null;
      return decryptedPlan.emergency_contacts[index] || null;
    },
    [decryptedPlan]
  );

  /**
   * Quick access to emergency services (no auth required)
   */
  const getEmergencyServices = useCallback(() => {
    return {
      crisis_hotline: '988', // US National Suicide Prevention Lifeline
      emergency: '911',
    };
  }, []);

  // ============================================================================
  // RETURN VIEWMODEL INTERFACE
  // ============================================================================

  return {
    // Crisis plan state
    hasCrisisPlan,
    crisisPlanSummary,
    crisisPlan: decryptedPlan,
    needsReview,
    daysSinceReview,

    // CRUD operations
    createCrisisPlan,
    updateCrisisPlan,
    deleteCrisisPlan,
    getCrisisPlanContent,
    markAsReviewed,

    // Security
    isAuthenticated,
    requestBiometricAuth,
    clearAuth,
    checkAuth,
    authError,

    // Emergency access (no auth required)
    getEmergencyContact,
    getEmergencyServices,

    // Loading state
    isLoading,
  };
};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Encrypt crisis plan (placeholder - implement with crypto library)
 */
async function encryptCrisisPlan(plan: CrisisPlan): Promise<string> {
  // TODO: Implement AES-256 encryption
  return JSON.stringify(plan);
}

/**
 * Decrypt crisis plan (placeholder - implement with crypto library)
 */
async function decryptCrisisPlan(encrypted: string): Promise<CrisisPlan> {
  // TODO: Implement AES-256 decryption
  return JSON.parse(encrypted);
}
