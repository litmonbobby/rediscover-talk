# ADR 001: State Management with Zustand

**Status**: Accepted
**Date**: 2025-10-21
**Deciders**: Enterprise Architect, React Native Team
**Framework Compliance**: LitmonCloud Framework v3.1, React Native MVVM-C patterns

---

## Context

Rediscover Talk requires robust state management for 8 core mental wellness features with offline-first capabilities, persistent storage, and minimal overhead. Mental health data requires reliable state synchronization across components, secure persistence, and seamless offline→online transitions.

**Key Requirements**:
- Global state for user auth, preferences, feature data
- Persistent storage with AsyncStorage for offline-first UX
- Type-safe state management with TypeScript strict mode
- Minimal re-renders for performance (60fps target)
- Modular architecture supporting 8 feature modules
- <500KB initial bundle size constraint

---

## Decision

**Chosen Solution**: Zustand with AsyncStorage persistence middleware

**Implementation Details**:
- Feature-based state slices (auth, wellness, journal, conversation, crisis, etc.)
- `persist` middleware with `createJSONStorage(() => AsyncStorage)`
- Selective state persistence (exclude sensitive data from AsyncStorage)
- Type-safe stores with TypeScript inference
- Hook-based consumption in ViewModels

---

## Alternatives Considered

### Option 1: Redux + Redux Toolkit
**Pros**:
- Industry standard, extensive ecosystem
- DevTools integration for debugging
- Well-documented patterns

**Cons**:
- ❌ Boilerplate overhead (~30% more code than Zustand)
- ❌ Requires Provider wrapping (increases bundle size)
- ❌ Complex setup for persistence (redux-persist configuration)
- ❌ Steeper learning curve for team
- ❌ Performance impact from connect() wrapping

**Verdict**: Too heavyweight for mental wellness app requirements

### Option 2: React Context + useReducer
**Pros**:
- Native React solution, no dependencies
- Simple mental model

**Cons**:
- ❌ Performance issues with frequent updates (mood tracking)
- ❌ No built-in persistence mechanism
- ❌ Difficult to scale across 8 features
- ❌ Context Provider nesting complexity
- ❌ Manual optimization required (useMemo, useCallback)

**Verdict**: Insufficient for complex state requirements

### Option 3: MobX
**Pros**:
- Reactive programming model
- Automatic dependency tracking

**Cons**:
- ❌ Decorators require additional Babel configuration
- ❌ Less TypeScript-friendly than Zustand
- ❌ Observable pattern adds mental overhead
- ❌ Smaller React Native community adoption

**Verdict**: Configuration complexity outweighs benefits

### Option 4: Zustand (Selected)
**Pros**:
- ✅ Minimal API surface (~1KB core library)
- ✅ No Provider wrapping needed
- ✅ Native TypeScript support with type inference
- ✅ Built-in persistence middleware for AsyncStorage
- ✅ Slice pattern for modular feature organization
- ✅ Excellent performance (minimal re-renders)
- ✅ DevTools support via middleware
- ✅ Simple mental model (hook-based)

**Cons**:
- Smaller ecosystem than Redux (acceptable trade-off)
- Less opinionated (requires architectural discipline)

**Verdict**: Optimal balance of simplicity, performance, and features

---

## Consequences

### Positive

1. **Performance**: Minimal re-renders with selector-based subscriptions reduce overhead
2. **Developer Experience**: Simple API reduces cognitive load, faster onboarding
3. **Bundle Size**: ~1KB core + AsyncStorage (~15KB) << Redux Toolkit (~100KB+)
4. **Type Safety**: Full TypeScript inference without manual typing overhead
5. **Offline-First**: Native persistence support via middleware aligns with mental health data requirements
6. **Scalability**: Slice pattern supports 8+ feature modules without architectural changes

### Negative

1. **Ecosystem**: Fewer third-party libraries compared to Redux (mitigated by LitmonCloud services integration)
2. **Opinionation**: Requires team discipline to maintain slice organization (addressed via code review guidelines)

### Neutral

1. **Learning Curve**: Team must learn Zustand patterns (estimated 1-2 days vs. 1 week for Redux)
2. **Migration Path**: Future migration to Redux possible if requirements change (minimal lock-in)

---

## Implementation Example

```typescript
// src/store/slices/wellnessSlice.ts
import { StateCreator } from 'zustand';
import { MoodEntry } from '../../core/models/MoodEntry';

export interface WellnessSlice {
  moodEntries: MoodEntry[];
  addMoodEntry: (entry: MoodEntry) => void;
  updateMoodEntry: (id: string, updates: Partial<MoodEntry>) => void;
  deleteMoodEntry: (id: string) => void;
}

export const createWellnessSlice: StateCreator<WellnessSlice> = (set) => ({
  moodEntries: [],

  addMoodEntry: (entry) =>
    set((state) => ({
      moodEntries: [entry, ...state.moodEntries]
    })),

  updateMoodEntry: (id, updates) =>
    set((state) => ({
      moodEntries: state.moodEntries.map(entry =>
        entry.id === id ? { ...entry, ...updates } : entry
      ),
    })),

  deleteMoodEntry: (id) =>
    set((state) => ({
      moodEntries: state.moodEntries.filter(entry => entry.id !== id),
    })),
});

// src/store/index.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createWellnessSlice, WellnessSlice } from './slices/wellnessSlice';
import { createAuthSlice, AuthSlice } from './slices/authSlice';

type AppStore = WellnessSlice & AuthSlice;

export const useAppStore = create<AppStore>()(
  persist(
    (...a) => ({
      ...createWellnessSlice(...a),
      ...createAuthSlice(...a),
    }),
    {
      name: 'rediscover-talk-storage',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({
        // Persist only non-sensitive data
        auth: { isAuthenticated: state.isAuthenticated },
        wellness: { moodEntries: state.moodEntries },
        // Exclude tokens, encrypted journal entries
      }),
    }
  )
);

// Usage in ViewModel
export const useWellnessViewModel = () => {
  const { moodEntries, addMoodEntry } = useAppStore();

  const createMoodEntry = useCallback(async (input: CreateMoodInput) => {
    const entry = await WellnessService.create(input);
    addMoodEntry(entry);
  }, [addMoodEntry]);

  return { moodEntries, createMoodEntry };
};
```

---

## Compliance

**LitmonCloud Framework Standards**:
- ✅ MVVM-C Separation: State management isolated from View layer
- ✅ TypeScript Strict: Full type inference with no `any` types
- ✅ Dependency Injection: Services injected via ViewModels
- ✅ Testability: Pure functions in slices enable unit testing
- ✅ Performance: Selector-based subscriptions prevent unnecessary re-renders

**React Native Best Practices**:
- ✅ AsyncStorage for persistent storage (recommended)
- ✅ Hook-based architecture (React 18 patterns)
- ✅ Bundle size optimization (<500KB initial target)

---

## References

- [Zustand Documentation](https://github.com/pmndrs/zustand)
- [Zustand Persist Middleware](https://github.com/pmndrs/zustand/blob/main/docs/integrations/persisting-store-data.md)
- LitmonCloud Framework v3.1 Architecture Guide
- React Native Performance Best Practices

---

## Review & Approval

**Approved By**: Enterprise Architect
**Review Date**: 2025-10-21
**Next Review**: 2026-01-21 (Quarterly)
