## Rediscover Talk - State Management Guide

**Version**: 1.0.0
**Architecture**: Zustand with AsyncStorage Persistence
**Framework**: LitmonCloud Mobile Development Framework v3.1

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Store Structure](#store-structure)
4. [Usage Patterns](#usage-patterns)
5. [Data Flow](#data-flow)
6. [Persistence Strategy](#persistence-strategy)
7. [Sync Management](#sync-management)
8. [Performance Optimization](#performance-optimization)
9. [Testing](#testing)
10. [Best Practices](#best-practices)

---

## Overview

Rediscover Talk implements **offline-first state management** using Zustand with AsyncStorage persistence. The architecture supports 8 core mental wellness features with type-safe, performant state operations.

**Key Features**:
- ✅ Feature-based state slices for modularity
- ✅ AsyncStorage persistence with selective data sync
- ✅ TypeScript strict mode with full type inference
- ✅ Optimistic updates for better UX
- ✅ Background sync with conflict resolution
- ✅ Minimal re-renders via selector subscriptions
- ✅ Encrypted sensitive data (journal, crisis plan) via SecureStorage

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   React Components (Views)                   │
│         ┌──────────────────────────────────────┐            │
│         │  const { user, login } = useAppStore()│            │
│         │  const trends = useAppStore(selectMoodTrends) │   │
│         └──────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
                            ↓ ↑ (subscribe / dispatch)
┌─────────────────────────────────────────────────────────────┐
│                      Zustand Store                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │ AuthSlice│ │MoodSlice │ │Journal   │ │ Crisis   │       │
│  │          │ │          │ │Slice     │ │ Slice    │ ...   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
└─────────────────────────────────────────────────────────────┘
                            ↓ ↑
┌─────────────────────────────────────────────────────────────┐
│                    Persistence Layer                         │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  AsyncStorage    │  │  SecureStorage   │                │
│  │  (Metadata)      │  │  (Encrypted)     │                │
│  └──────────────────┘  └──────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                            ↓ ↑
┌─────────────────────────────────────────────────────────────┐
│                   Background Sync Service                    │
│         (Syncs unsynced data when online)                   │
└─────────────────────────────────────────────────────────────┘
```

### Store Organization

```typescript
src/stores/
├── index.ts                 # Main store export
├── slices/                  # Feature-based state slices
│   ├── authSlice.ts         # User session & authentication
│   ├── moodSlice.ts         # Mood tracking & analytics
│   ├── journalSlice.ts      # Journal metadata
│   ├── crisisSlice.ts       # Crisis plan metadata
│   ├── promptsSlice.ts      # Daily prompts & responses
│   ├── exercisesSlice.ts    # Family exercises
│   ├── breathingSlice.ts    # Breathing sessions
│   └── aiGuideSlice.ts      # AI conversation metadata
├── selectors/               # Derived state & memoization
│   ├── moodSelectors.ts     # Mood analytics
│   ├── journalSelectors.ts  # Search results
│   ├── exercisesSelectors.ts# Progress tracking
│   └── breathingSelectors.ts# Session stats
└── middleware/              # Custom middleware
    ├── syncMiddleware.ts    # Background sync
    └── loggingMiddleware.ts # Development logging
```

---

## Store Structure

### 1. AuthSlice

**Purpose**: User authentication, session management, preferences

**State**:
```typescript
{
  user: UserProfile | null
  isAuthenticated: boolean
  isAnonymous: boolean
  preferences: UserPreferences
  session: SessionState
  sync: SyncState
}
```

**Actions**:
- `setUser(user)` - Set authenticated user
- `updateUserProfile(updates)` - Update profile fields
- `logout()` - Clear authentication state
- `updatePreferences(updates)` - Update user preferences
- `startSync()` / `completeSync()` - Manage sync state

**Usage**:
```typescript
import { useAppStore } from '../stores';

const LoginScreen = () => {
  const { user, isAuthenticated, setUser } = useAppStore();

  const handleLogin = async (email, password) => {
    const user = await AuthService.login(email, password);
    setUser(user);
  };

  return (
    <View>
      {isAuthenticated ? (
        <Text>Welcome, {user?.display_name}</Text>
      ) : (
        <LoginForm onSubmit={handleLogin} />
      )}
    </View>
  );
};
```

---

### 2. MoodSlice

**Purpose**: Mood tracking, trends, analytics

**State**:
```typescript
{
  entries: MoodEntry[]
  trends: MoodTrend | null
  filters: MoodFilters
  loading: MoodLoadingState
  lastSyncedAt: Date | null
  unsyncedEntries: string[]
}
```

**Actions**:
- `addMoodEntry(entry)` - Create new mood entry
- `updateMoodEntry(id, updates)` - Update existing entry
- `setMoodTrends(trends)` - Set analytics data
- `markAsSynced(id)` - Mark entry as synced

**Computed Helpers**:
- `getAverageMood(period)` - Calculate average for week/month/year
- `getMoodStreak()` - Get current tracking streak
- `getMoodEntriesByDateRange(start, end)` - Filter by date

**Usage**:
```typescript
import { useAppStore, selectMoodTrends } from '../stores';

const MoodHistoryScreen = () => {
  // Optimized selector subscription (only re-renders when trends change)
  const trends = useAppStore(selectMoodTrends);
  const { entries, addMoodEntry, setMoodTrends } = useAppStore();

  useEffect(() => {
    // Calculate trends from entries
    const calculated = calculateTrends(entries);
    setMoodTrends(calculated);
  }, [entries]);

  const handleCreateMood = async (input) => {
    const entry = await MoodRepository.create(input);
    addMoodEntry(entry); // Optimistic update
  };

  return (
    <View>
      <MoodChart data={trends} />
      <MoodList entries={entries} />
      <AddMoodButton onPress={handleCreateMood} />
    </View>
  );
};
```

---

### 3. JournalSlice

**Purpose**: Journal entry metadata, drafts, search

**State**:
```typescript
{
  journalMetadata: JournalMetadata[]  // Title, tags, word count
  drafts: JournalDraft[]
  tags: string[]
  searchHistory: string[]
  searchFilters: JournalSearchFilters
  loading: JournalLoadingState
  unsyncedEntries: string[]
}
```

**Security Note**: Encrypted content stored separately in SecureStorage via `JournalRepository`. Only metadata persisted in Zustand.

**Actions**:
- `addJournalMetadata(metadata)` - Add new entry metadata
- `createDraft(draft)` - Save draft for later
- `toggleFavorite(id)` - Mark as favorite
- `setSearchFilters(filters)` - Set search criteria

**Selectors**:
- `selectFilteredJournals(state)` - Apply search filters
- `selectJournalSearchResults(state)` - Ranked search results

**Usage**:
```typescript
import { useAppStore, selectFilteredJournals } from '../stores';

const JournalListScreen = () => {
  const filtered = useAppStore(selectFilteredJournals);
  const { addJournalMetadata, setSearchFilters } = useAppStore();

  const handleCreateJournal = async (input) => {
    // Save encrypted content via repository
    const encrypted = await JournalRepository.create(input);

    // Add metadata to store
    addJournalMetadata({
      id: encrypted.id,
      title: input.title,
      word_count: input.content.split(' ').length,
      tags: input.tags,
      // ... other metadata
    });
  };

  const handleSearch = (query) => {
    setSearchFilters({ query });
  };

  return (
    <View>
      <SearchBar onSearch={handleSearch} />
      <JournalList entries={filtered} />
    </View>
  );
};
```

---

### 4. CrisisSlice

**Purpose**: Crisis plan metadata (details in SecureStorage)

**State**:
```typescript
{
  hasCrisisPlan: boolean
  lastReviewedAt: Date | null
  emergencyContactCount: number
  professionalContactCount: number
}
```

**Actions**:
- `setHasCrisisPlan(has)` - Track plan existence
- `setLastReviewed(date)` - Update review timestamp
- `setEmergencyContactCount(count)` - Update contact count

---

### 5. PromptsSlice

**Purpose**: Daily conversation prompts & responses

**State**:
```typescript
{
  todayPrompt: ConversationPrompt | null
  responses: PromptResponse[]
  completionStreak: number
  unsyncedResponses: string[]
}
```

**Actions**:
- `setTodayPrompt(prompt)` - Set daily prompt
- `addResponse(response)` - Save user response
- `setCompletionStreak(streak)` - Update streak

---

### 6. ExercisesSlice

**Purpose**: Family exercise completions & progress

**State**:
```typescript
{
  completions: ExerciseCompletion[]
  favoriteExercises: string[]
  exerciseStreak: number
  unsyncedCompletions: string[]
}
```

**Selectors**:
- `selectExerciseProgress(state)` - Calculate progress stats

---

### 7. BreathingSlice

**Purpose**: Breathing exercise sessions & analytics

**State**:
```typescript
{
  sessions: BreathingSession[]
  favoriteBreathingExercises: string[]
  breathingStreak: number
  activeSessionId: string | null
}
```

**Selectors**:
- `selectBreathingStats(state)` - Mood/anxiety improvements

---

### 8. AIGuideSlice

**Purpose**: AI conversation metadata (messages in SecureStorage)

**State**:
```typescript
{
  conversationCount: number
  lastConversationAt: Date | null
  isTyping: boolean
  activeConversationId: string | null
}
```

---

## Usage Patterns

### Pattern 1: Whole Store Access

```typescript
const Component = () => {
  const { user, moodEntries, addMoodEntry } = useAppStore();
  // Re-renders whenever ANY store property changes
};
```

**Use When**: Component needs multiple slices or frequently changing data.

---

### Pattern 2: Selector Subscription (Recommended)

```typescript
const Component = () => {
  // Only re-renders when trends change
  const trends = useAppStore(selectMoodTrends);
  const addEntry = useAppStore(state => state.addMoodEntry);

  return <MoodChart data={trends} />;
};
```

**Use When**: Optimizing performance by subscribing to specific derived state.

---

### Pattern 3: Shallow Comparison

```typescript
import { shallow } from 'zustand/shallow';

const Component = () => {
  const { entries, trends } = useAppStore(
    state => ({ entries: state.entries, trends: state.trends }),
    shallow // Shallow comparison of returned object
  );
};
```

**Use When**: Selecting multiple properties with shallow equality.

---

## Data Flow

### Unidirectional Flow Pattern

```
User Action → ViewModel → Repository → Store Update → View Re-render
```

**Example: Create Mood Entry**

```typescript
// 1. User Action
<Button onPress={handleCreateMood} />

// 2. ViewModel (custom hook)
const useWellnessViewModel = () => {
  const addMoodEntry = useAppStore(state => state.addMoodEntry);
  const incrementPendingChanges = useAppStore(state => state.incrementPendingChanges);

  const createMoodEntry = useCallback(async (input) => {
    try {
      // Optimistic update
      const optimisticEntry = { ...input, id: generateId(), is_synced: false };
      addMoodEntry(optimisticEntry);
      incrementPendingChanges();

      // 3. Repository (persistence)
      const savedEntry = await MoodRepository.create(input);

      // 4. Store Update
      addMoodEntry({ ...savedEntry, is_synced: true });

    } catch (error) {
      // Rollback optimistic update
      deleteMoodEntry(optimisticEntry.id);
      showError(error.message);
    }
  }, [addMoodEntry]);

  return { createMoodEntry };
};

// 5. View Re-render (automatic)
const Component = () => {
  const entries = useAppStore(state => state.entries);
  return <MoodList entries={entries} />;
};
```

---

### Optimistic Updates

**Pattern**:
1. Immediately update store (optimistic)
2. Perform async operation (repository save)
3. Confirm or rollback based on result

**Benefits**:
- Instant UI feedback
- Better perceived performance
- Works offline

**Example**:
```typescript
const handleDelete = async (id) => {
  const backup = getMoodEntryById(id);

  // Optimistic delete
  deleteMoodEntry(id);

  try {
    await MoodRepository.delete(id);
  } catch (error) {
    // Rollback on failure
    addMoodEntry(backup);
    showError('Delete failed');
  }
};
```

---

## Persistence Strategy

### Two-Tier Storage Model

| Data Type | Storage | Encryption | Persistence |
|-----------|---------|------------|-------------|
| User Profile | AsyncStorage | ❌ No | ✅ Yes |
| Mood Entries | AsyncStorage | ❌ No | ✅ Yes |
| Journal Metadata | AsyncStorage | ❌ No | ✅ Yes |
| **Journal Content** | SecureStorage | ✅ AES-256 | ✅ Yes |
| **Crisis Plan** | SecureStorage | ✅ AES-256 | ✅ Yes |
| **Auth Tokens** | Keychain | ✅ OS-level | ✅ Yes |

### Selective Persistence

```typescript
// Only persist non-sensitive data in AsyncStorage
partialize: (state) => ({
  auth: {
    user: state.user, // OK - no tokens
    isAuthenticated: state.isAuthenticated,
    preferences: state.preferences,
  },
  mood: {
    entries: state.entries, // OK - non-sensitive
  },
  journal: {
    journalMetadata: state.journalMetadata, // OK - metadata only
    drafts: state.drafts, // Temporary, cleared on logout
  },
  // Exclude: tokens, encrypted content, session-specific state
})
```

### Migration Strategy

```typescript
migrate: (persistedState, version) => {
  if (version === 0) {
    // Example: Add new field to mood entries
    return {
      ...persistedState,
      mood: {
        ...persistedState.mood,
        entries: persistedState.mood.entries.map(entry => ({
          ...entry,
          newField: defaultValue, // Add missing field
        })),
      },
    };
  }
  return persistedState;
}
```

---

## Sync Management

### Background Sync

**Sync Middleware** automatically syncs unsynced data when network is available.

**Features**:
- Network state monitoring
- Exponential backoff on failures
- Retry logic with max attempts
- Per-feature sync tracking

**Configuration**:
```typescript
const syncConfig = {
  enabled: true,
  syncInterval: 60000, // 1 minute
  maxRetries: 3,
  backoffMultiplier: 2,
};
```

**Sync Flow**:
```
Network Connected → Check Unsynced Data → Sync Each Feature → Update Store
```

**Conflict Resolution** (Supabase RLS):
- Server timestamp wins
- Client changes merge if non-conflicting
- User notified of conflicts requiring manual resolution

---

## Performance Optimization

### 1. Selector Memoization

```typescript
// ❌ Bad - Creates new array on every render
const entries = useAppStore(state => state.entries.filter(e => e.mood_level > 3));

// ✅ Good - Memoized selector
const selectHighMoodEntries = (state) =>
  state.entries.filter(e => e.mood_level > 3);

const entries = useAppStore(selectHighMoodEntries);
```

### 2. Shallow Comparison

```typescript
import { shallow } from 'zustand/shallow';

// Only re-renders if user OR preferences change (shallow comparison)
const { user, preferences } = useAppStore(
  state => ({ user: state.user, preferences: state.preferences }),
  shallow
);
```

### 3. Subscription Splitting

```typescript
// ❌ Bad - Re-renders on any auth change
const { user, isAuthenticated, session } = useAppStore();

// ✅ Good - Only re-renders when user changes
const user = useAppStore(state => state.user);
```

### 4. Computed Values in Selectors

```typescript
// Move expensive calculations to selectors
export const selectMoodTrends = (state) => {
  // Expensive calculation happens once per state change
  return calculateTrends(state.entries);
};
```

---

## Testing

### Unit Testing Slices

```typescript
import { create } from 'zustand';
import { createMoodSlice } from '../slices/moodSlice';

describe('MoodSlice', () => {
  it('should add mood entry', () => {
    const store = create(createMoodSlice);
    const entry = { id: '1', mood_level: 4, /* ... */ };

    store.getState().addMoodEntry(entry);

    expect(store.getState().entries).toHaveLength(1);
    expect(store.getState().entries[0]).toEqual(entry);
  });

  it('should mark entry as synced', () => {
    const store = create(createMoodSlice);
    const entry = { id: '1', is_synced: false, /* ... */ };

    store.getState().addMoodEntry(entry);
    store.getState().markAsSynced('1');

    expect(store.getState().entries[0].is_synced).toBe(true);
  });
});
```

### Integration Testing with React Testing Library

```typescript
import { renderHook, act } from '@testing-library/react-hooks';
import { useAppStore } from '../stores';

describe('MoodStore Integration', () => {
  it('should handle optimistic updates', async () => {
    const { result } = renderHook(() => useAppStore());

    const entry = { mood_level: 4, notes: 'Test' };

    await act(async () => {
      await result.current.addMoodEntry(entry);
    });

    expect(result.current.entries).toHaveLength(1);
  });
});
```

---

## Best Practices

### 1. Keep Slices Focused

**❌ Avoid**:
```typescript
// God slice with everything
export interface AppSlice {
  user: User;
  moods: Mood[];
  journals: Journal[];
  // ... 50 more properties
}
```

**✅ Prefer**:
```typescript
// Focused slices
export interface AuthSlice { user, login, logout }
export interface MoodSlice { entries, addEntry, ... }
```

---

### 2. Use Selectors for Derived State

**❌ Avoid**:
```typescript
const Component = () => {
  const entries = useAppStore(state => state.entries);
  const average = entries.reduce(...) / entries.length; // Recalculated every render
};
```

**✅ Prefer**:
```typescript
const selectAverageMood = (state) =>
  state.entries.reduce(...) / state.entries.length;

const Component = () => {
  const average = useAppStore(selectAverageMood); // Cached
};
```

---

### 3. Validate Data Before Persisting

```typescript
import { validateSchemaOrThrow } from '../types/schemas';

const addMoodEntry = (entry) => {
  // Validate with Zod schema
  const validated = validateSchemaOrThrow(MoodEntrySchema, entry);

  set(state => ({
    entries: [validated, ...state.entries],
  }));
};
```

---

### 4. Clear Sensitive Data on Logout

```typescript
export const resetStore = async () => {
  const state = useAppStore.getState();

  // Clear all slices
  state.logout();
  state.clearMoodEntries();
  state.clearJournalMetadata();
  // ...

  // Clear AsyncStorage
  await AsyncStorage.removeItem('rediscover-talk-storage');

  // Clear SecureStorage
  await SecureStorageService.clearAll();
};
```

---

### 5. Monitor Sync Status

```typescript
const SyncIndicator = () => {
  const { isSyncing, pendingChanges, syncError } = useAppStore(
    state => state.sync,
    shallow
  );

  if (syncError) return <ErrorBanner message={syncError} />;
  if (isSyncing) return <SyncSpinner />;
  if (pendingChanges > 0) return <Badge count={pendingChanges} />;

  return null;
};
```

---

## Summary

Rediscover Talk's state management implements:

✅ **Zustand** for lightweight, type-safe state
✅ **AsyncStorage** persistence for offline-first UX
✅ **SecureStorage** for encrypted sensitive data
✅ **Feature-based slices** for modularity
✅ **Optimistic updates** for instant feedback
✅ **Background sync** with conflict resolution
✅ **Selector optimization** for performance

**Next Steps**: See `docs/DATA_FLOW_DIAGRAMS.md` for visual flow charts and `docs/BACKEND_INTEGRATION.md` for Supabase sync patterns.
