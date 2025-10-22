# ADR 005: Data Synchronization Strategy

**Status**: Accepted
**Date**: 2025-10-21
**Deciders**: iOS Backend Integration Specialist, Enterprise Architect, Backend Team
**Framework Compliance**: LitmonCloud Mobile Development Framework v3.1

---

## Context

Rediscover Talk requires a robust data synchronization strategy to handle offline-first mobile usage patterns while maintaining data consistency with the Supabase backend. The app must function seamlessly regardless of network connectivity, with transparent background synchronization that doesn't disrupt the user experience.

**Key Requirements**:
- 100% offline functionality for all core features
- Transparent background synchronization without blocking UI
- Data consistency between local storage and Supabase backend
- Minimal battery and data usage impact
- Conflict resolution for concurrent modifications
- User awareness of sync status without intrusive notifications
- Recovery from sync failures and partial syncs

**Mental Health App Constraints**:
- Users may be in crisis situations with unreliable connectivity
- Synchronization failures must not result in data loss
- Sensitive data (journal entries, crisis plans) requires encryption before transmission
- Background sync must not drain battery during therapeutic sessions
- Users need confidence that their data is safely persisted locally

**Technical Context**:
- React Native with AsyncStorage and react-native-keychain for local persistence
- Supabase PostgreSQL backend with Row Level Security
- NetworkService with retry logic and exponential backoff
- NetInfo for network connectivity monitoring
- AppState for foreground/background detection

---

## Decision

**Selected Solution**: **Background Queue-Based Synchronization** with exponential backoff retry logic

**Architecture**:
- **Local-First Writes**: All mutations saved locally immediately for instant UI updates
- **Sync Queue**: Pending operations queued for background synchronization
- **Opportunistic Sync**: Background worker processes queue when network available
- **Exponential Backoff**: Failed syncs retry with increasing delays (5s, 10s, 20s, 40s, 80s)
- **Conflict Resolution**: Last-write-wins strategy with server timestamp comparison
- **Sync Status Tracking**: Per-item sync state (pending, in_progress, synced, failed)
- **Manual Retry**: User-initiated sync for failed operations via UI indicator

**Sync Trigger Events**:
1. App foreground (sync on app resume)
2. Network connectivity restored (NetInfo listener)
3. Periodic background sync (every 5 minutes when online)
4. User-initiated refresh (pull-to-refresh gestures)
5. Scheduled sync during low-battery mode (every 30 minutes)

---

## Alternatives Considered

### Option 1: Immediate Synchronization

**Approach**: Every local mutation immediately triggers API request to Supabase

**Pros**:
- ✅ Real-time data consistency between client and server
- ✅ Simple implementation (no queue management)
- ✅ Users see immediate sync status feedback
- ✅ No complex conflict resolution needed

**Cons**:
- ❌ App unusable without network connectivity (violates offline-first requirement)
- ❌ UI blocked during network requests (poor user experience)
- ❌ High battery consumption from constant network activity
- ❌ Poor performance in areas with spotty connectivity
- ❌ Failed requests immediately visible to user (anxiety-inducing for mental health app)
- ❌ Network errors interrupt therapeutic journaling sessions
- ❌ Mobile data consumption excessive for users on limited plans

**Verdict**: Violates offline-first requirement and creates poor UX for mental health app users who may be in crisis situations with unreliable connectivity.

---

### Option 2: Batched Synchronization

**Approach**: Collect mutations over time, sync in batches every N seconds (e.g., every 30 seconds)

**Pros**:
- ✅ Reduced network requests compared to immediate sync
- ✅ Better battery efficiency through request batching
- ✅ Offline functionality for short periods (within batch window)
- ✅ Network error handling consolidated to batch operations

**Cons**:
- ❌ Data loss risk if app crashes before batch sync completes
- ❌ Fixed batch interval creates unnecessary sync attempts when offline
- ❌ Still blocks user experience during batch sync operations
- ❌ Battery drain from periodic syncs even when network unavailable
- ❌ Sync window creates confusion (users unsure if data saved)
- ❌ Batch failures affect multiple operations simultaneously
- ❌ Complex error handling for partial batch failures

**Verdict**: Better than immediate sync but still creates UX issues and battery drain. Fixed intervals don't adapt to network conditions or app usage patterns.

---

### Option 3: Scheduled Synchronization

**Approach**: Sync only at specific intervals (e.g., app foreground, background, explicit user action)

**Pros**:
- ✅ Maximum offline functionality
- ✅ Minimal battery consumption (syncs only when necessary)
- ✅ User control over sync timing (privacy-conscious users)
- ✅ Clear sync boundaries (foreground/background transitions)

**Cons**:
- ❌ Long delays between syncs (data inconsistency for hours)
- ❌ Users must remember to manually sync (cognitive burden)
- ❌ Large sync payloads after long offline periods
- ❌ Conflict resolution complexity increases with sync delays
- ❌ Background app refresh not guaranteed on iOS (system manages schedule)
- ❌ Users may forget to sync before uninstalling app (data loss)
- ❌ No immediate feedback that data is safely backed up

**Verdict**: Too passive for mental health app where users need confidence their therapeutic journal entries and crisis plans are safely backed up. Long sync delays increase anxiety.

---

### Option 4: Background Queue-Based Synchronization - Selected

**Approach**: Local-first writes with background queue worker processing opportunistic syncs

**Pros**:
- ✅ **100% Offline Functionality**: All operations work immediately without network
- ✅ **Instant UI Feedback**: Users see changes immediately, no blocking
- ✅ **Battery Efficient**: Syncs only when network available, adapts to connectivity
- ✅ **Resilient to Failures**: Exponential backoff prevents battery drain from failed retries
- ✅ **Transparent Background Sync**: Users don't notice sync operations
- ✅ **Flexible Sync Triggers**: App foreground, network restored, periodic checks
- ✅ **Graceful Degradation**: Failed syncs retry automatically without user intervention
- ✅ **Low Cognitive Load**: Users don't think about sync, just use app naturally
- ✅ **Data Loss Prevention**: Local queue persists across app restarts
- ✅ **Mental Health UX**: Non-intrusive, reliable, confidence-building

**Cons**:
- ⚠️ More complex implementation (sync queue, worker, retry logic)
- ⚠️ Requires queue persistence and management
- ⚠️ Conflict resolution needed for concurrent modifications (mitigated by last-write-wins)

**Verdict**: Optimal balance of offline functionality, user experience, battery efficiency, and reliability. Implementation complexity justified by mental health app requirements.

---

## Consequences

### Positive

1. **Offline-First User Experience**: Users can journal, log moods, and update crisis plans regardless of connectivity. Therapeutic sessions never interrupted by network issues.

2. **Battery Efficiency**: Sync queue worker only active when network available. Exponential backoff prevents battery drain from failed retries. Low-battery mode reduces sync frequency.

3. **Data Consistency**: Last-write-wins conflict resolution with server timestamp comparison ensures eventual consistency. Conflicts rare due to single-user data model.

4. **Resilient to Network Failures**: Exponential backoff (5s → 80s) prevents overwhelming server with retries. Failed syncs automatically retry when network restored.

5. **User Confidence**: Sync status indicators (🔄 syncing, ✅ synced, ⚠️ failed) provide transparency without anxiety. Manual retry option for failed operations.

6. **Developer Experience**: Sync abstracted to SyncService, repositories use simple `addToQueue()` API. No manual sync logic in feature code.

7. **Scalability**: Queue-based architecture handles bursts of offline activity (e.g., extended journaling session) without overwhelming backend.

8. **Privacy-Conscious**: Users can disable background sync in settings, relying on manual sync only. Encrypted data synced over TLS.

9. **Testing-Friendly**: Sync queue easily mocked for unit tests. Integration tests can simulate network conditions.

10. **Performance Metrics**: Sync queue length, retry counts, and failure rates provide visibility into system health.

### Negative

1. **Implementation Complexity**: Requires SyncService, queue persistence, retry logic, conflict resolution, and network monitoring. Mitigated by LitmonCloud NetworkService providing retry foundation.

2. **Queue Management**: Sync queue must be persisted across app restarts and cleaned up after successful syncs. Requires AsyncStorage management.

3. **Conflict Resolution Edge Cases**: Last-write-wins may discard changes in rare concurrent modification scenarios (e.g., user edits on two devices). Mitigated by single-device usage pattern and server timestamps.

4. **Background Sync Limitations**: iOS background app refresh not guaranteed. Syncs may be delayed until app foreground. Mitigated by foreground sync trigger.

### Neutral

1. **Sync Status UI**: Requires UI indicators for sync state (pending, syncing, synced, failed). Standard practice for offline-first apps.

2. **Testing**: Mock sync queue and network conditions required for comprehensive tests. Standard practice with offline functionality.

---

## Implementation Details

### Sync Queue Data Model

**TypeScript Interface**:
```typescript
export interface SyncQueueItem {
  id: string;                    // Unique queue item ID
  type: string;                  // Data type: 'mood_entry', 'journal_entry', etc.
  operation: 'create' | 'update' | 'delete';
  data: any;                     // Payload to sync (encrypted if sensitive)
  attempts: number;              // Retry count
  lastAttempt: Date | null;      // Last sync attempt timestamp
  createdAt: Date;               // Queue entry creation time
  error?: string;                // Last error message (for debugging)
}

export interface SyncStatus {
  is_synced: boolean;            // True if successfully synced to server
  synced_at: Date | null;        // Server sync timestamp
  sync_error?: string;           // Last sync error message
}
```

### Sync Service Implementation

**Core Architecture**:
```typescript
export class SyncService {
  private static instance: SyncService;
  private readonly SYNC_QUEUE_KEY = '@rediscover_talk:sync_queue';
  private readonly SYNC_INTERVAL = 5 * 60 * 1000; // 5 minutes
  private readonly MAX_RETRIES = 5;
  private syncTimer: NodeJS.Timeout | null = null;
  private isSyncing = false;

  private constructor(
    private networkService: NetworkService,
    private storageService: StorageService
  ) {
    this.startBackgroundSync();
    this.setupNetworkListener();
    this.setupAppStateListener();
  }

  static getInstance(): SyncService {
    if (!SyncService.instance) {
      SyncService.instance = new SyncService(
        NetworkService.getInstance(),
        StorageService.getInstance()
      );
    }
    return SyncService.instance;
  }

  // Add item to sync queue
  async addToQueue(item: Omit<SyncQueueItem, 'id' | 'attempts' | 'lastAttempt' | 'createdAt'>): Promise<void> {
    const queue = await this.getSyncQueue();
    const queueItem: SyncQueueItem = {
      id: `sync_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
      attempts: 0,
      lastAttempt: null,
      createdAt: new Date(),
      ...item
    };
    queue.push(queueItem);
    await this.saveSyncQueue(queue);

    // Trigger immediate sync attempt if online
    const isOnline = await this.networkService.isConnected();
    if (isOnline) {
      this.processSyncQueue();
    }
  }

  // Background sync worker
  private async processSyncQueue(): Promise<void> {
    if (this.isSyncing) return;
    this.isSyncing = true;

    try {
      const queue = await this.getSyncQueue();
      if (queue.length === 0) return;

      const isOnline = await this.networkService.isConnected();
      if (!isOnline) return;

      const itemsToSync = queue.filter(item =>
        item.attempts < this.MAX_RETRIES &&
        this.shouldRetry(item)
      );

      for (const item of itemsToSync) {
        try {
          await this.syncItem(item);
          // Remove successfully synced item from queue
          const updatedQueue = queue.filter(q => q.id !== item.id);
          await this.saveSyncQueue(updatedQueue);
        } catch (error) {
          // Update retry count and last attempt
          item.attempts += 1;
          item.lastAttempt = new Date();
          item.error = error instanceof Error ? error.message : 'Unknown error';
          await this.saveSyncQueue(queue);
        }
      }
    } finally {
      this.isSyncing = false;
    }
  }

  // Exponential backoff calculation
  private shouldRetry(item: SyncQueueItem): boolean {
    if (item.attempts === 0) return true;
    if (!item.lastAttempt) return true;

    const backoffDelays = [5000, 10000, 20000, 40000, 80000]; // 5s, 10s, 20s, 40s, 80s
    const delay = backoffDelays[Math.min(item.attempts - 1, backoffDelays.length - 1)];
    const timeSinceLastAttempt = Date.now() - item.lastAttempt.getTime();

    return timeSinceLastAttempt >= delay;
  }

  // Sync individual item to Supabase
  private async syncItem(item: SyncQueueItem): Promise<void> {
    const endpoint = this.getEndpoint(item.type, item.operation);

    switch (item.operation) {
      case 'create':
        await this.networkService.post(endpoint, item.data);
        break;
      case 'update':
        await this.networkService.put(`${endpoint}/${item.data.id}`, item.data);
        break;
      case 'delete':
        await this.networkService.delete(`${endpoint}/${item.data.id}`);
        break;
    }
  }

  // Network connectivity listener
  private setupNetworkListener(): void {
    NetInfo.addEventListener(state => {
      if (state.isConnected && state.isInternetReachable) {
        this.processSyncQueue();
      }
    });
  }

  // App foreground/background listener
  private setupAppStateListener(): void {
    AppState.addEventListener('change', (nextAppState) => {
      if (nextAppState === 'active') {
        // App came to foreground, trigger sync
        this.processSyncQueue();
      }
    });
  }

  // Periodic background sync
  private startBackgroundSync(): void {
    this.syncTimer = setInterval(() => {
      this.processSyncQueue();
    }, this.SYNC_INTERVAL);
  }

  // Queue persistence
  private async getSyncQueue(): Promise<SyncQueueItem[]> {
    const queue = await this.storageService.get<SyncQueueItem[]>(this.SYNC_QUEUE_KEY);
    return queue || [];
  }

  private async saveSyncQueue(queue: SyncQueueItem[]): Promise<void> {
    await this.storageService.set(this.SYNC_QUEUE_KEY, queue);
  }

  // Manual sync trigger (for UI button)
  async triggerManualSync(): Promise<void> {
    await this.processSyncQueue();
  }

  // Get sync status for UI
  async getSyncStatus(): Promise<{ pending: number; failed: number; lastSync: Date | null }> {
    const queue = await this.getSyncQueue();
    const pending = queue.filter(item => item.attempts < this.MAX_RETRIES).length;
    const failed = queue.filter(item => item.attempts >= this.MAX_RETRIES).length;

    const lastSyncedItem = queue
      .filter(item => item.lastAttempt !== null)
      .sort((a, b) => (b.lastAttempt?.getTime() || 0) - (a.lastAttempt?.getTime() || 0))[0];

    return {
      pending,
      failed,
      lastSync: lastSyncedItem?.lastAttempt || null
    };
  }

  // Cleanup
  destroy(): void {
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
    }
  }
}
```

### Repository Integration

**Example: MoodEntryRepository with Sync Queue**:
```typescript
export class MoodEntryRepository implements BaseRepository<MoodEntry, CreateMoodEntryInput, Partial<MoodEntry>> {
  private readonly STORAGE_KEY = '@rediscover_talk:mood_entries';
  private syncService: SyncService;
  private storageService: StorageService;

  constructor() {
    this.syncService = SyncService.getInstance();
    this.storageService = StorageService.getInstance();
  }

  async create(input: CreateMoodEntryInput): Promise<MoodEntry> {
    const newEntry: MoodEntry = {
      id: uuidv4(),
      created_at: new Date(),
      updated_at: new Date(),
      synced_at: null,
      is_synced: false,
      ...input
    };

    // 1. Save locally immediately (instant UI feedback)
    const entries = await this.getAll();
    entries.unshift(newEntry);
    await this.storageService.set(this.STORAGE_KEY, entries);

    // 2. Add to sync queue for background sync
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'create',
      data: newEntry
    });

    return newEntry;
  }

  async update(id: string, input: Partial<MoodEntry>): Promise<MoodEntry> {
    const entries = await this.getAll();
    const index = entries.findIndex(e => e.id === id);

    if (index === -1) {
      throw new Error('Mood entry not found');
    }

    const updatedEntry: MoodEntry = {
      ...entries[index],
      ...input,
      updated_at: new Date(),
      is_synced: false, // Mark as unsynced
      synced_at: null
    };

    // 1. Update locally immediately
    entries[index] = updatedEntry;
    await this.storageService.set(this.STORAGE_KEY, entries);

    // 2. Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'update',
      data: updatedEntry
    });

    return updatedEntry;
  }

  async delete(id: string): Promise<void> {
    const entries = await this.getAll();
    const entryToDelete = entries.find(e => e.id === id);

    if (!entryToDelete) {
      throw new Error('Mood entry not found');
    }

    // 1. Delete locally immediately
    const updatedEntries = entries.filter(e => e.id !== id);
    await this.storageService.set(this.STORAGE_KEY, updatedEntries);

    // 2. Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'delete',
      data: { id }
    });
  }

  async getAll(): Promise<MoodEntry[]> {
    const entries = await this.storageService.get<MoodEntry[]>(this.STORAGE_KEY);
    return entries || [];
  }
}
```

### Conflict Resolution Strategy

**Last-Write-Wins Algorithm**:
```typescript
export class ConflictResolver {
  static resolveConflict<T extends { updated_at: Date }>(
    localVersion: T,
    serverVersion: T
  ): T {
    // Compare timestamps - most recent update wins
    const localTime = new Date(localVersion.updated_at).getTime();
    const serverTime = new Date(serverVersion.updated_at).getTime();

    if (serverTime > localTime) {
      // Server version is newer, accept server changes
      return serverVersion;
    } else {
      // Local version is newer, keep local changes
      return localVersion;
    }
  }
}
```

**Conflict Detection in Sync**:
```typescript
private async syncItem(item: SyncQueueItem): Promise<void> {
  try {
    // Attempt to sync local changes to server
    await this.networkService.put(`/api/${item.type}/${item.data.id}`, item.data);
  } catch (error) {
    if (error.response?.status === 409) {
      // Conflict detected - server has newer version
      const serverVersion = error.response.data;
      const resolvedVersion = ConflictResolver.resolveConflict(item.data, serverVersion);

      // Update local storage with resolved version
      await this.updateLocalStorage(item.type, resolvedVersion);

      // If server version won, no need to retry sync
      if (resolvedVersion === serverVersion) {
        return;
      }

      // If local version won, retry sync with resolved data
      item.data = resolvedVersion;
      throw error; // Retry sync
    } else {
      throw error;
    }
  }
}
```

---

## Sync Status UI

### Visual Indicators

**Per-Item Sync Status**:
```typescript
export const SyncStatusBadge: React.FC<{ isSynced: boolean; syncError?: string }> = ({ isSynced, syncError }) => {
  if (syncError) {
    return (
      <View style={styles.badge}>
        <Icon name="alert-circle" size={16} color="#F44336" />
        <Text style={styles.errorText}>Sync failed</Text>
        <TouchableOpacity onPress={() => SyncService.getInstance().triggerManualSync()}>
          <Text style={styles.retryText}>Retry</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (!isSynced) {
    return (
      <View style={styles.badge}>
        <ActivityIndicator size="small" color="#2196F3" />
        <Text style={styles.syncingText}>Syncing...</Text>
      </View>
    );
  }

  return (
    <View style={styles.badge}>
      <Icon name="check-circle" size={16} color="#4CAF50" />
      <Text style={styles.syncedText}>Synced</Text>
    </View>
  );
};
```

**Global Sync Status Header**:
```typescript
export const SyncStatusHeader: React.FC = () => {
  const [syncStatus, setSyncStatus] = useState({ pending: 0, failed: 0, lastSync: null });

  useEffect(() => {
    const updateStatus = async () => {
      const status = await SyncService.getInstance().getSyncStatus();
      setSyncStatus(status);
    };

    updateStatus();
    const interval = setInterval(updateStatus, 10000); // Update every 10s

    return () => clearInterval(interval);
  }, []);

  if (syncStatus.pending === 0 && syncStatus.failed === 0) {
    return null; // Hide when all synced
  }

  return (
    <View style={styles.header}>
      {syncStatus.pending > 0 && (
        <Text style={styles.pendingText}>
          {syncStatus.pending} items syncing...
        </Text>
      )}
      {syncStatus.failed > 0 && (
        <TouchableOpacity onPress={() => SyncService.getInstance().triggerManualSync()}>
          <Text style={styles.failedText}>
            {syncStatus.failed} items failed. Tap to retry.
          </Text>
        </TouchableOpacity>
      )}
    </View>
  );
};
```

---

## Performance Metrics

### Success Metrics

- **Sync Success Rate**: ≥99% of queue items successfully synced within 5 retry attempts
- **Sync Latency**: ≤10 seconds from queue entry to successful sync (when online)
- **Battery Impact**: ≤2% battery drain per hour from background sync
- **Data Consistency**: 100% eventual consistency (all local changes synced to server)
- **Conflict Rate**: ≤0.1% of syncs result in conflicts (single-device usage pattern)

### Monitoring

**Sync Queue Metrics**:
```typescript
export interface SyncMetrics {
  queueLength: number;           // Current queue size
  syncSuccessRate: number;       // Successful syncs / total attempts
  averageSyncLatency: number;    // Average time from queue to sync (ms)
  conflictRate: number;          // Conflicts / total syncs
  failedItems: SyncQueueItem[];  // Items exceeding MAX_RETRIES
}
```

---

## Testing Strategy

### Unit Tests

**SyncService Tests**:
```typescript
describe('SyncService', () => {
  it('should add item to queue', async () => {
    const syncService = SyncService.getInstance();
    await syncService.addToQueue({
      type: 'mood_entry',
      operation: 'create',
      data: { mood_level: 4 }
    });

    const queue = await syncService['getSyncQueue']();
    expect(queue.length).toBe(1);
    expect(queue[0].type).toBe('mood_entry');
  });

  it('should retry failed syncs with exponential backoff', async () => {
    const syncService = SyncService.getInstance();
    const item: SyncQueueItem = {
      id: 'test_1',
      type: 'mood_entry',
      operation: 'create',
      data: {},
      attempts: 2,
      lastAttempt: new Date(Date.now() - 15000), // 15s ago
      createdAt: new Date()
    };

    // Should retry (backoff delay for attempt 2 is 10s)
    expect(syncService['shouldRetry'](item)).toBe(true);

    // Update to recent attempt
    item.lastAttempt = new Date(Date.now() - 5000); // 5s ago
    expect(syncService['shouldRetry'](item)).toBe(false);
  });
});
```

### Integration Tests

**Mock Network Conditions**:
```typescript
describe('Offline Sync Integration', () => {
  it('should queue operations when offline and sync when online', async () => {
    // Simulate offline
    NetInfo.fetch.mockResolvedValue({ isConnected: false, isInternetReachable: false });

    const repository = new MoodEntryRepository();
    const entry = await repository.create({
      user_id: 'user_1',
      mood_level: 4,
      timestamp: new Date()
    });

    // Verify local save
    const localEntries = await repository.getAll();
    expect(localEntries).toContainEqual(entry);
    expect(entry.is_synced).toBe(false);

    // Verify queue
    const queue = await SyncService.getInstance()['getSyncQueue']();
    expect(queue.length).toBe(1);

    // Simulate online
    NetInfo.fetch.mockResolvedValue({ isConnected: true, isInternetReachable: true });
    await SyncService.getInstance().triggerManualSync();

    // Verify sync
    await waitFor(() => {
      const updatedQueue = SyncService.getInstance()['getSyncQueue']();
      expect(updatedQueue.length).toBe(0);
    });
  });
});
```

---

## Compliance

### HIPAA Requirements

**Technical Safeguards**:
- ✅ Encryption in transit (TLS 1.3 for all Supabase API calls)
- ✅ Encryption at rest (AES-256 for journal entries and crisis plans before sync)
- ✅ Audit logging (sync queue tracks all operations with timestamps)
- ✅ Automatic logoff (sync queue cleared on user logout)
- ✅ Access controls (Row Level Security enforced on server)

**Administrative Safeguards**:
- ✅ Data retention policies (sync queue cleanup after successful sync)
- ✅ User consent (sync settings in privacy preferences)
- ✅ Privacy notice (sync status transparency in UI)

---

## References

- [LitmonCloud NetworkService](../../ReactNative/src/services/NetworkService.ts)
- [LitmonCloud StorageService](../../ReactNative/src/services/StorageService.ts)
- [ADR 003: Data Persistence & Encryption](003-data-persistence-encryption.md)
- [ADR 004: Backend Platform Selection](004-backend-platform-selection.md)
- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [React Native NetInfo](https://github.com/react-native-netinfo/react-native-netinfo)
- [React Native AppState](https://reactnative.dev/docs/appstate)

---

## Review & Approval

**Approved By**: iOS Backend Integration Specialist, Enterprise Architect, Backend Team
**Security Review**: Passed (encryption before sync, TLS in transit)
**Privacy Review**: Passed (user control, transparent sync status)
**Performance Review**: Approved (battery efficient, exponential backoff)
**Review Date**: 2025-10-21
**Next Review**: 2025-11-21 (Monthly - Critical System)
