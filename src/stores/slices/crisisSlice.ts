/**
 * Crisis Slice - Crisis Plan & Emergency Resources
 *
 * Manages crisis plan metadata and emergency contact references.
 * Sensitive plan details stored in SecureStorage via CrisisRepository.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator } from 'zustand';

export interface CrisisSlice {
  hasCrisisPlan: boolean;
  lastReviewedAt: Date | null;
  emergencyContactCount: number;
  professionalContactCount: number;
  isEditing: boolean;
  error: string | null;

  setHasCrisisPlan: (has: boolean) => void;
  setLastReviewed: (date: Date) => void;
  setEmergencyContactCount: (count: number) => void;
  setProfessionalContactCount: (count: number) => void;
  setEditing: (isEditing: boolean) => void;
  setCrisisError: (error: string | null) => void;
  clearCrisisPlan: () => void;
}

export const createCrisisSlice: StateCreator<CrisisSlice> = (set) => ({
  hasCrisisPlan: false,
  lastReviewedAt: null,
  emergencyContactCount: 0,
  professionalContactCount: 0,
  isEditing: false,
  error: null,

  setHasCrisisPlan: (has) => set(() => ({ hasCrisisPlan: has })),
  setLastReviewed: (date) => set(() => ({ lastReviewedAt: date })),
  setEmergencyContactCount: (count) =>
    set(() => ({ emergencyContactCount: count })),
  setProfessionalContactCount: (count) =>
    set(() => ({ professionalContactCount: count })),
  setEditing: (isEditing) => set(() => ({ isEditing })),
  setCrisisError: (error) => set(() => ({ error })),
  clearCrisisPlan: () =>
    set(() => ({
      hasCrisisPlan: false,
      lastReviewedAt: null,
      emergencyContactCount: 0,
      professionalContactCount: 0,
    })),
});
