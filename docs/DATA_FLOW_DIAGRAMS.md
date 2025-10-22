# Rediscover Talk - Data Flow Diagrams

**Version**: 1.0.0
**Architecture**: MVVM-C with Zustand State Management
**Framework**: LitmonCloud Mobile Development Framework v3.1

---

## Table of Contents

1. [Unidirectional Data Flow](#unidirectional-data-flow)
2. [Mood Entry Creation Flow](#mood-entry-creation-flow)
3. [Journal Entry Encryption Flow](#journal-entry-encryption-flow)
4. [Offline-First Sync Flow](#offline-first-sync-flow)
5. [State Update Propagation](#state-update-propagation)
6. [Conflict Resolution Flow](#conflict-resolution-flow)
7. [Authentication Flow](#authentication-flow)
8. [Crisis Plan Access Flow](#crisis-plan-access-flow)

---

## Unidirectional Data Flow

**Pattern**: View → ViewModel → Service → Repository → Storage → State Update → View Refresh

```mermaid
graph LR
    A[User Interaction] -->|Tap Button| B[View Component]
    B -->|Call Action| C[ViewModel Hook]
    C -->|Business Logic| D[Service Layer]
    D -->|CRUD Operation| E[Repository]
    E -->|Persist Data| F[Storage Layer]
    F -->|AsyncStorage| G[State Update]
    F -->|SecureStorage| G
    G -->|Zustand Store| H[State Changed]
    H -->|Subscription| B
    B -->|Re-render| I[Updated UI]

    style A fill:#4CAF50
    style I fill:#4CAF50
    style G fill:#FF9800
    style F fill:#2196F3
```

**Key Principles**:
- Data flows in **one direction only**
- State updates trigger **automatic re-renders**
- No direct state manipulation from views
- All mutations go through **actions**

---

## Mood Entry Creation Flow

**Scenario**: User creates a new mood entry with activities and notes

```mermaid
sequenceDiagram
    participant U as User
    participant V as MoodTrackerView
    participant VM as useWellnessViewModel
    participant S as MoodSlice
    participant R as MoodRepository
    participant AS as AsyncStorage
    participant SVC as SyncService

    U->>V: Tap "Log Mood" (Level 4, Exercise, Notes)
    V->>VM: createMoodEntry(input)

    Note over VM: Validation & optimistic update
    VM->>S: addMoodEntry(optimisticEntry)
    S->>S: Add to entries[] (unsynced)
    S-->>V: State updated
    V->>V: Instant UI update ✨

    VM->>R: create(input)
    R->>AS: Save to AsyncStorage
    AS-->>R: Saved successfully
    R-->>VM: Return saved entry

    VM->>S: updateMoodEntry(id, {is_synced: false})
    S->>S: Mark as unsynced
    S-->>V: Final state update

    Note over SVC: Background sync (when online)
    SVC->>R: syncEntries(unsyncedIds)
    R->>SVC: Supabase sync
    SVC->>S: markAsSynced(id)
    S->>S: Update is_synced: true
    S-->>V: Sync complete indicator
```

**Timeline**:
1. **0ms**: User taps button
2. **~50ms**: Optimistic update → UI shows new entry immediately
3. **~100ms**: AsyncStorage save completes
4. **~1000ms**: Background sync to Supabase (if online)

**Error Handling**:
- If AsyncStorage fails → Rollback optimistic update
- If sync fails → Retry with exponential backoff
- User sees sync status indicator (syncing, synced, error)

---

## Journal Entry Encryption Flow

**Scenario**: User creates encrypted journal entry

```mermaid
sequenceDiagram
    participant U as User
    participant V as JournalEditorView
    participant VM as useJournalViewModel
    participant JS as JournalSlice
    participant R as JournalRepository
    participant SS as SecureStorageService
    participant AS as AsyncStorage

    U->>V: Write journal content
    U->>V: Tap "Save"
    V->>VM: createJournalEntry(title, content, tags)

    Note over VM: Client-side encryption
    VM->>VM: Generate encryption key
    VM->>VM: Encrypt content (AES-256)

    VM->>R: create(encryptedEntry)

    par Store Encrypted Content
        R->>SS: setItem(id, encryptedContent)
        SS->>SS: Store in Keychain
        SS-->>R: Stored securely
    and Store Metadata
        R->>AS: Save metadata (title, tags, wordCount)
        AS-->>R: Metadata saved
    end

    R-->>VM: Created entry

    VM->>JS: addJournalMetadata(metadata)
    JS->>JS: Add to journalMetadata[]
    JS-->>V: State updated
    V->>V: Show success message ✅

    Note over U: Reading journal entry
    U->>V: Tap journal entry
    V->>VM: getJournalEntry(id)
    VM->>R: getById(id)
    R->>SS: getItem(id)
    SS-->>R: Encrypted content
    R->>R: Decrypt content
    R-->>VM: Decrypted entry
    VM-->>V: Display content
```

**Security Layers**:
1. **Client-side encryption** before persistence
2. **AES-256** encryption standard
3. **Keychain storage** (OS-level security)
4. **Biometric authentication** required for access
5. **Auto-lock** after inactivity

**Metadata vs Content**:
- **Metadata** (AsyncStorage): `{id, title, tags, wordCount, created_at}`
- **Content** (SecureStorage): Encrypted full journal text

---

## Offline-First Sync Flow

**Scenario**: User creates data offline, then comes back online

```mermaid
graph TB
    A[User Creates Mood Entry] --> B{Network Available?}

    B -->|Yes| C[Immediate Sync]
    C --> D[Save to AsyncStorage]
    C --> E[Sync to Supabase]
    E --> F[Mark as Synced]

    B -->|No| G[Offline Mode]
    G --> H[Save to AsyncStorage]
    H --> I[Mark as Unsynced]
    I --> J[Add to Sync Queue]

    J --> K[NetInfo: Network Restored]
    K --> L[Sync Middleware Activated]
    L --> M{Check Sync Queue}

    M --> N[Batch Sync Unsynced Data]
    N --> O{Sync Success?}

    O -->|Yes| P[Mark All as Synced]
    O -->|No| Q[Retry with Backoff]

    Q --> R{Max Retries?}
    R -->|No| N
    R -->|Yes| S[Show Sync Error]

    P --> T[Clear Sync Queue]
    T --> U[Show Sync Success ✅]

    style A fill:#4CAF50
    style G fill:#FF9800
    style U fill:#4CAF50
    style S fill:#F44336
```

**Sync Queue Management**:
```typescript
{
  unsyncedEntries: ['mood-1', 'mood-2'],
  unsyncedJournals: ['journal-1'],
  unsyncedResponses: ['prompt-1'],
  pendingChanges: 4
}
```

**Backoff Strategy**:
- Attempt 1: Immediate
- Attempt 2: +2 seconds
- Attempt 3: +4 seconds
- Attempt 4: +8 seconds (max)
- Then: Manual retry or wait for next sync interval

---

## State Update Propagation

**Scenario**: State change triggers component re-renders

```mermaid
graph LR
    A[User Action] -->|addMoodEntry| B[Zustand Store]

    B --> C{Which Components Subscribe?}

    C -->|useAppStore| D[MoodListScreen]
    C -->|selectMoodTrends| E[MoodChartScreen]
    C -->|selectRecentMoods| F[HomeScreen]

    D -->|Full Re-render| G[List Updates]
    E -->|Memoized Selector| H{Trends Changed?}
    F -->|Shallow Comparison| I{Recent Moods Changed?}

    H -->|Yes| J[Chart Re-renders]
    H -->|No| K[Skip Re-render ⚡]

    I -->|Yes| L[Home Updates]
    I -->|No| M[Skip Re-render ⚡]

    style K fill:#4CAF50
    style M fill:#4CAF50
    style G fill:#FF9800
```

**Optimization Techniques**:

1. **Selector Subscriptions** (Prevent Unnecessary Re-renders)
   ```typescript
   // ✅ Only re-renders when trends change
   const trends = useAppStore(selectMoodTrends);
   ```

2. **Shallow Comparison**
   ```typescript
   // ✅ Only re-renders if user OR preferences change
   const { user, preferences } = useAppStore(
     state => ({ user: state.user, preferences: state.preferences }),
     shallow
   );
   ```

3. **Memoized Selectors**
   ```typescript
   // ✅ Calculation cached, not recomputed on every render
   export const selectMoodTrends = (state) => {
     return expensiveCalculation(state.entries);
   };
   ```

---

## Conflict Resolution Flow

**Scenario**: User edits mood entry offline, server has newer version

```mermaid
sequenceDiagram
    participant U as User (Offline)
    participant L as Local Store
    participant S as Sync Service
    participant SB as Supabase
    participant R as Resolver

    Note over U,L: User edits mood entry offline
    U->>L: updateMoodEntry(id, { notes: "Updated offline" })
    L->>L: Save locally (timestamp: 10:00)
    L->>L: Mark as unsynced

    Note over U,S: User comes back online
    U->>S: Network connected
    S->>SB: Sync unsynced entries

    SB-->>S: Server version (timestamp: 10:05)
    Note over S: Server version newer!

    S->>R: resolveConflict(local, server)

    R->>R: Apply conflict resolution strategy

    alt Server Wins (Default)
        R->>L: updateMoodEntry(id, serverVersion)
        R->>U: Notify: "Entry updated from server"
    else Client Wins
        R->>SB: force_update(localVersion)
        R->>L: markAsSynced(id)
    else Merge
        R->>R: Merge non-conflicting fields
        R->>SB: update(mergedVersion)
        R->>L: updateMoodEntry(id, mergedVersion)
    else Manual Resolution
        R->>U: Show conflict dialog
        U->>R: Choose version
        R->>L: Apply chosen version
    end

    R->>L: markAsSynced(id)
    L-->>U: Sync complete
```

**Conflict Resolution Strategies**:

1. **Server Wins (Default)** - Mental health data prioritizes latest clinical state
2. **Client Wins** - User explicitly forces local changes
3. **Merge** - Non-conflicting fields merged (e.g., tags + notes)
4. **Manual** - Critical data (crisis plan) requires user decision

**Supabase RLS Conflict Detection**:
```sql
-- Detect conflicts via updated_at timestamp
SELECT * FROM mood_entries
WHERE id = $1 AND updated_at > $2;
```

---

## Authentication Flow

**Scenario**: User logs in with email/password

```mermaid
sequenceDiagram
    participant U as User
    participant V as LoginScreen
    participant VM as useAuthViewModel
    participant AS as AuthSlice
    participant R as AuthRepository
    participant SB as Supabase
    participant KC as Keychain

    U->>V: Enter email/password
    U->>V: Tap "Login"
    V->>VM: login(email, password)

    VM->>R: authenticate(email, password)
    R->>SB: auth.signIn(email, password)

    alt Success
        SB-->>R: { user, session, access_token }

        par Store Tokens Securely
            R->>KC: setItem('access_token', token)
            R->>KC: setItem('refresh_token', refresh)
        and Update Store
            R->>AS: setUser(user)
            AS->>AS: isAuthenticated = true
            AS-->>V: State updated
        end

        V->>V: Navigate to MainTabs
    else Failure
        SB-->>R: AuthError
        R-->>VM: Error: "Invalid credentials"
        VM->>AS: setAuthError(error)
        AS-->>V: Show error message ❌
    end

    Note over VM,R: Background token refresh
    R->>R: Schedule refresh (expires_in - 5min)
    R->>SB: auth.refreshToken()
    SB-->>R: New access_token
    R->>KC: Update tokens
```

**Token Management**:
- **Access Token**: Keychain (OS-encrypted)
- **Refresh Token**: Keychain (OS-encrypted)
- **User Profile**: AsyncStorage (non-sensitive)
- **Session State**: Zustand Store (in-memory)

**Security**:
- Tokens never persisted in AsyncStorage
- Auto-refresh 5 minutes before expiry
- Logout clears both stores and Keychain

---

## Crisis Plan Access Flow

**Scenario**: User accesses encrypted crisis plan

```mermaid
sequenceDiagram
    participant U as User
    participant V as CrisisPlanScreen
    participant VM as useCrisisViewModel
    participant CS as CrisisSlice
    participant BA as BiometricAuth
    participant R as CrisisRepository
    participant SS as SecureStorage

    U->>V: Tap "View Crisis Plan"
    V->>VM: getCrisisPlan()

    VM->>CS: Check hasCrisisPlan
    CS-->>VM: hasCrisisPlan = true

    VM->>BA: authenticateBiometric()

    alt Biometric Success
        BA-->>VM: Authenticated ✅

        VM->>R: getCrisisPlan()
        R->>SS: getItem('crisis_plan')
        SS-->>R: Encrypted plan

        R->>R: Decrypt with user key
        R-->>VM: Decrypted plan

        VM->>CS: setLastReviewed(now)
        CS-->>V: Display crisis plan
    else Biometric Failure
        BA-->>VM: Authentication failed ❌
        VM->>V: Show "Authentication required"
        V->>V: Return to previous screen
    else No Biometric Available
        BA-->>VM: Biometric not available
        VM->>V: Show PIN entry fallback
    end

    Note over V: User reviews plan
    U->>V: Tap emergency contact
    V->>V: Initiate phone call (no auth needed)
```

**Access Control**:
1. **Biometric Required**: Face ID / Touch ID / Fingerprint
2. **Fallback**: 4-digit PIN (if biometric unavailable)
3. **Emergency Access**: Direct dial without auth
4. **Auto-Lock**: Re-auth after 5 minutes inactivity

**Crisis Plan Structure**:
```typescript
{
  encrypted_warning_signs: string,      // AES-256 encrypted
  encrypted_coping_strategies: string,  // AES-256 encrypted
  encrypted_support_contacts: string,   // AES-256 encrypted
  emergency_instructions: string,       // Plaintext (for quick access)
  last_reviewed_at: Date                // Metadata in store
}
```

---

## Summary

**Data Flow Principles**:
✅ **Unidirectional**: View → ViewModel → Service → Repository → Store → View
✅ **Optimistic Updates**: Instant UI feedback with rollback on failure
✅ **Offline-First**: Local persistence with background sync
✅ **Security**: Multi-layer encryption for sensitive data
✅ **Performance**: Selector optimization prevents unnecessary re-renders
✅ **Reliability**: Exponential backoff retry logic for sync failures

**Next Steps**: See `STATE_MANAGEMENT_GUIDE.md` for implementation details and `BACKEND_INTEGRATION.md` for Supabase sync patterns.
