# ViewModel Quick Reference Card

**Project**: Rediscover Talk - Mental Wellness App
**Last Updated**: October 21, 2025

---

## Quick Import Guide

```typescript
// ViewModel imports
import { useWellnessViewModel } from '../viewmodels/useWellnessViewModel';
import { useJournalViewModel } from '../viewmodels/useJournalViewModel';
import { useCrisisViewModel } from '../viewmodels/useCrisisViewModel';
import { useAuthViewModel } from '../viewmodels/useAuthViewModel';
```

---

## useWellnessViewModel

### Common Operations

```typescript
const {
  // Mood tracking
  moodEntries,              // MoodEntry[] - All mood entries
  trends,                   // MoodTrend - Week/month analytics
  createMoodEntry,          // (input) => Promise<void>
  getMoodStreak,            // number - Current streak days

  // Breathing exercises
  breathingStats,           // Stats - Session analytics
  startBreathingSession,    // (input) => Promise<void>
  completeBreathingSession, // (mood, anxiety) => Promise<void>

  // Family exercises
  exerciseProgress,         // Progress - Completion stats
  completeExercise,         // (input) => Promise<void>

  // Overall wellness
  wellnessSummary,          // Summary - Overall score + metrics
  isLoading,                // boolean
} = useWellnessViewModel();
```

### Example: Log Mood

```typescript
await createMoodEntry({
  user_id: userId,
  mood_level: 4,                    // 1-5 scale
  activities: ['exercise', 'sleep'], // Activities today
  notes: 'Feeling great!',          // Optional notes
});
```

### Example: Start Breathing Session

```typescript
await startBreathingSession({
  user_id: userId,
  exercise_id: 'box-breathing',
  duration_seconds: 300,
  mood_before: 2,
  anxiety_before: 7,
  mood_after: 0,        // Set to 0 initially
  anxiety_after: 0,     // Set to 0 initially
});
```

---

## useJournalViewModel

### Common Operations

```typescript
const {
  // Journal data
  journals,                 // JournalMetadata[] - All journal metadata
  searchResults,            // JournalMetadata[] - Filtered results
  journalStats,             // Stats - Total entries, words, tags

  // CRUD operations
  createJournal,            // (input) => Promise<JournalMetadata>
  updateJournal,            // (id, updates) => Promise<void>
  deleteJournal,            // (id) => Promise<void>
  getJournalContent,        // (id) => Promise<string> - Decrypted content

  // Search & filtering
  searchJournals,           // (query: string) => void
  filterByTag,              // (tag: string) => void
  filterByMood,             // (level: number) => void
  clearFilters,             // () => void

  // Draft management
  drafts,                   // JournalDraft[] - Unsaved drafts
  saveDraft,                // (draft) => string - Returns draft ID
  publishDraft,             // (draftId, userId) => Promise<JournalMetadata>

  // Tags
  tags,                     // string[] - All tags
  createTag,                // (tag: string) => void

  isLoading,                // boolean
  encryptionError,          // string | null
} = useJournalViewModel();
```

### Example: Create Journal

```typescript
await createJournal({
  user_id: userId,
  title: 'Gratitude Journal',
  content: 'Today I am grateful for...',
  tags: ['gratitude', 'reflection'],
  mood_level: 4,
});
```

### Example: Search Journals

```typescript
// Search by text
searchJournals('gratitude');

// Filter by tag
filterByTag('reflection');

// Filter by mood
filterByMood(4);

// Clear all filters
clearFilters();
```

### Example: Save Draft

```typescript
const draftId = saveDraft({
  title: 'Draft Title',
  content: 'Work in progress...',
  tags: ['draft'],
  mood_level: null,
});

// Later, publish draft
await publishDraft(draftId, userId);
```

---

## useCrisisViewModel

### Common Operations

```typescript
const {
  // Crisis plan state
  hasCrisisPlan,            // boolean
  crisisPlanSummary,        // Summary - Contact counts, review status
  crisisPlan,               // CrisisPlan | null - Decrypted plan
  needsReview,              // boolean - True if >90 days since review
  daysSinceReview,          // number | null

  // CRUD operations
  createCrisisPlan,         // (input) => Promise<CrisisPlan>
  updateCrisisPlan,         // (updates) => Promise<CrisisPlan>
  deleteCrisisPlan,         // () => Promise<void>
  getCrisisPlanContent,     // () => Promise<CrisisPlan | null>
  markAsReviewed,           // () => void

  // Security
  isAuthenticated,          // boolean
  requestBiometricAuth,     // () => Promise<boolean>
  clearAuth,                // () => void
  authError,                // string | null

  // Emergency access (NO AUTH REQUIRED)
  getEmergencyContact,      // (index: number) => EmergencyContact | null
  getEmergencyServices,     // () => { crisis_hotline, emergency }

  isLoading,                // boolean
} = useCrisisViewModel();
```

### Example: Access Crisis Plan

```typescript
// Requires biometric authentication
const authenticated = await requestBiometricAuth();

if (authenticated) {
  const plan = await getCrisisPlanContent();
  if (plan) {
    console.log('Warning signs:', plan.warning_signs);
    console.log('Coping strategies:', plan.coping_strategies);
  }
}
```

### Example: Emergency Services

```typescript
// NO AUTHENTICATION REQUIRED - Always accessible
const services = getEmergencyServices();

Alert.alert('Emergency Services', `
  Crisis Hotline: ${services.crisis_hotline}
  Emergency: ${services.emergency}
`);
```

### Example: Create Crisis Plan

```typescript
await createCrisisPlan({
  user_id: userId,
  warning_signs: [
    'Feeling hopeless',
    'Withdrawing from friends',
    'Changes in sleep patterns',
  ],
  coping_strategies: [
    'Call a friend',
    'Go for a walk',
    'Practice deep breathing',
  ],
  emergency_contacts: [
    {
      name: 'John Doe',
      relationship: 'Friend',
      phone: '555-0123',
    },
  ],
  professional_contacts: [
    {
      name: 'Dr. Smith',
      specialty: 'Therapist',
      phone: '555-0456',
    },
  ],
  safe_environment: 'Remove access to harmful items',
});
```

---

## useAuthViewModel

### Common Operations

```typescript
const {
  // User state
  user,                     // UserProfile | null
  isAuthenticated,          // boolean
  isAnonymous,              // boolean
  userDisplayInfo,          // { displayName, initials, avatarUrl, email }
  isSessionActive,          // boolean - Last activity within 30 min

  // Authentication
  login,                    // (credentials) => Promise<{ user, success }>
  signup,                   // (credentials) => Promise<{ user, success }>
  loginAnonymously,         // () => Promise<{ user, success }>
  logout,                   // () => Promise<{ success }>

  // Profile management
  updateProfile,            // (updates) => Promise<{ success }>
  uploadAvatar,             // (imageUri) => Promise<{ url, success }>

  // Preferences
  preferences,              // UserPreferences
  updatePreferences,        // (updates) => Promise<{ success }>
  toggleDarkMode,           // () => void
  updateLanguage,           // (language: string) => void
  toggleNotifications,      // (enabled: boolean) => void

  // Session management
  sessionInfo,              // { isActive, sessionStartedAt, lastActiveAt }
  updateActivity,           // () => void - Manual heartbeat

  // Sync management
  syncStatus,               // { isSyncing, lastSyncedAt, pendingChanges }
  triggerSync,              // () => Promise<void>

  // Password management
  changePassword,           // (current, new) => Promise<{ success }>
  requestPasswordReset,     // (email) => Promise<{ success }>

  isLoading,                // boolean
} = useAuthViewModel();
```

### Example: Login

```typescript
const result = await login({
  email: 'user@example.com',
  password: 'securePassword123',
});

if (result.success) {
  console.log('Logged in as:', result.user.display_name);
}
```

### Example: Guest Mode

```typescript
const result = await loginAnonymously();

if (result.success) {
  console.log('Anonymous session started');
}
```

### Example: Update Preferences

```typescript
// Toggle dark mode
toggleDarkMode();

// Update language
updateLanguage('es');

// Enable notifications
toggleNotifications(true);

// Or update multiple preferences
await updatePreferences({
  theme: 'dark',
  language: 'en',
  notifications: {
    enabled: true,
    daily_reminders: true,
    crisis_alerts: true,
  },
});
```

---

## Common Patterns

### Pattern 1: Optimistic Updates

```typescript
// ViewModels handle optimistic updates automatically
await createMoodEntry(input); // Instant UI update
```

**How it works**:
1. Immediately updates Zustand store (instant UI)
2. Persists to AsyncStorage in background
3. Rolls back if operation fails

### Pattern 2: Loading States

```typescript
function MyScreen() {
  const { data, isLoading } = useWellnessViewModel();

  if (isLoading) {
    return <LoadingSpinner />;
  }

  return <DataView data={data} />;
}
```

### Pattern 3: Error Handling

```typescript
const [error, setError] = useState(null);

const handleCreate = async () => {
  try {
    await createMoodEntry(input);
    setError(null);
  } catch (err) {
    setError(err.message);
    Alert.alert('Error', err.message);
  }
};
```

### Pattern 4: Selective Subscriptions

```typescript
// ✅ Only subscribes to needed properties
const { moodEntries, createMoodEntry } = useWellnessViewModel();

// ❌ Subscribes to entire ViewModel (unnecessary re-renders)
const viewModel = useWellnessViewModel();
```

---

## Performance Tips

### ✅ DO

```typescript
// Use selective subscriptions
const { moodEntries, createMoodEntry } = useWellnessViewModel();

// Use memoized selectors
const trends = useAppStore(selectMoodTrends);

// Clear sensitive data on unmount
useEffect(() => {
  return () => clearAuth();
}, []);
```

### ❌ DON'T

```typescript
// Don't subscribe to entire ViewModel
const viewModel = useWellnessViewModel();

// Don't use ViewModels in presentational components
function MoodCard() {
  const { updateMood } = useWellnessViewModel(); // Bad
}

// Don't forget to handle loading states
const { data } = useWellnessViewModel(); // Where's isLoading?
```

---

## Security Checklist

- [ ] ✅ Auth tokens stored in Keychain (not AsyncStorage)
- [ ] ✅ Journal content encrypted before storage
- [ ] ✅ Crisis plan requires biometric auth
- [ ] ✅ Session timeout after inactivity
- [ ] ✅ Emergency services always accessible (no auth)

---

## Troubleshooting

### "Authentication failed"
- Ensure biometric hardware is available
- Check session hasn't expired (5 min timeout)
- Try PIN fallback if biometric fails

### "Optimistic update not showing"
- Check network connectivity
- Verify user is authenticated
- Check for JavaScript errors in console

### "Sync not working"
- Trigger manual sync: `triggerSync()`
- Check `syncStatus.syncError` for error details
- Verify network connectivity

---

## File Locations

```
src/viewmodels/
├── useWellnessViewModel.ts     # Mood, Breathing, Exercise
├── useJournalViewModel.ts      # Encrypted journaling
├── useCrisisViewModel.ts       # Secure crisis plan
└── useAuthViewModel.ts         # Authentication & session
```

---

## Full Documentation

- **Integration Guide**: `docs/VIEWMODEL_INTEGRATION_GUIDE.md`
- **Implementation Summary**: `docs/VIEWMODEL_IMPLEMENTATION_SUMMARY.md`
- **State Management Guide**: `docs/STATE_MANAGEMENT_GUIDE.md`
- **Data Flow Diagrams**: `docs/DATA_FLOW_DIAGRAMS.md`

---

**Quick Reference Version**: 1.0
**Last Updated**: October 21, 2025
**Framework**: LitmonCloud Mobile Development Framework v3.1
