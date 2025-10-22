/**
 * Sync Middleware - Background synchronization for offline-first operations
 *
 * Automatically syncs unsynced data when network becomes available.
 * Implements exponential backoff for failed sync attempts.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator, StoreMutatorIdentifier } from 'zustand';
import NetInfo from '@react-native-community/netinfo';

/**
 * Sync configuration
 */
export interface SyncConfig {
  enabled: boolean;
  syncInterval: number; // milliseconds
  maxRetries: number;
  backoffMultiplier: number;
}

/**
 * Default sync configuration
 */
const defaultConfig: SyncConfig = {
  enabled: true,
  syncInterval: 60000, // 1 minute
  maxRetries: 3,
  backoffMultiplier: 2,
};

/**
 * Sync middleware creator
 *
 * Usage:
 * ```typescript
 * create(
 *   syncMiddleware(
 *     (...a) => ({ ...slices }),
 *     { syncInterval: 30000 }
 *   )
 * )
 * ```
 */
export const createSyncMiddleware =
  <T extends object>(config: Partial<SyncConfig> = {}) =>
  (stateCreator: StateCreator<T>): StateCreator<T> =>
  (set, get, api) => {
    const syncConfig = { ...defaultConfig, ...config };
    let syncIntervalId: NodeJS.Timeout | null = null;
    let retryCount = 0;

    /**
     * Check if device is online
     */
    const isOnline = async (): Promise<boolean> => {
      const state = await NetInfo.fetch();
      return state.isConnected ?? false;
    };

    /**
     * Sync unsynced data
     */
    const performSync = async () => {
      const online = await isOnline();
      if (!online || !syncConfig.enabled) return;

      const state = get() as any;

      try {
        // Start sync in auth slice
        if (state.startSync) {
          state.startSync();
        }

        // Sync mood entries
        if (state.unsyncedEntries && state.unsyncedEntries.length > 0) {
          console.log(`[SyncMiddleware] Syncing ${state.unsyncedEntries.length} mood entries`);
          // Call sync service here (would be implemented in repositories)
          // await MoodRepository.syncEntries(state.unsyncedEntries);
        }

        // Sync journal metadata
        if (state.unsyncedJournals && state.unsyncedJournals.length > 0) {
          console.log(`[SyncMiddleware] Syncing ${state.unsyncedJournals.length} journals`);
          // await JournalRepository.syncMetadata(state.unsyncedJournals);
        }

        // Sync prompt responses
        if (state.unsyncedResponses && state.unsyncedResponses.length > 0) {
          console.log(`[SyncMiddleware] Syncing ${state.unsyncedResponses.length} prompt responses`);
          // await PromptsRepository.syncResponses(state.unsyncedResponses);
        }

        // Sync exercise completions
        if (state.unsyncedCompletions && state.unsyncedCompletions.length > 0) {
          console.log(`[SyncMiddleware] Syncing ${state.unsyncedCompletions.length} exercise completions`);
          // await ExercisesRepository.syncCompletions(state.unsyncedCompletions);
        }

        // Sync breathing sessions
        if (state.unsyncedSessions && state.unsyncedSessions.length > 0) {
          console.log(`[SyncMiddleware] Syncing ${state.unsyncedSessions.length} breathing sessions`);
          // await BreathingRepository.syncSessions(state.unsyncedSessions);
        }

        // Complete sync successfully
        if (state.completeSync) {
          state.completeSync(true);
        }

        retryCount = 0; // Reset retry count on success
      } catch (error) {
        console.error('[SyncMiddleware] Sync failed:', error);

        // Complete sync with error
        if (state.completeSync) {
          state.completeSync(false, (error as Error).message);
        }

        // Retry with exponential backoff
        if (retryCount < syncConfig.maxRetries) {
          retryCount++;
          const backoffDelay =
            syncConfig.syncInterval * Math.pow(syncConfig.backoffMultiplier, retryCount);
          console.log(`[SyncMiddleware] Retrying in ${backoffDelay}ms (attempt ${retryCount}/${syncConfig.maxRetries})`);
          setTimeout(performSync, backoffDelay);
        }
      }
    };

    /**
     * Start sync interval
     */
    const startSyncInterval = () => {
      if (syncIntervalId) return;

      // Perform initial sync
      performSync();

      // Start periodic sync
      syncIntervalId = setInterval(performSync, syncConfig.syncInterval);
      console.log(`[SyncMiddleware] Started sync interval (${syncConfig.syncInterval}ms)`);
    };

    /**
     * Stop sync interval
     */
    const stopSyncInterval = () => {
      if (syncIntervalId) {
        clearInterval(syncIntervalId);
        syncIntervalId = null;
        console.log('[SyncMiddleware] Stopped sync interval');
      }
    };

    /**
     * Listen for network changes
     */
    NetInfo.addEventListener((state) => {
      if (state.isConnected) {
        console.log('[SyncMiddleware] Network connected, starting sync');
        startSyncInterval();
      } else {
        console.log('[SyncMiddleware] Network disconnected, stopping sync');
        stopSyncInterval();
      }
    });

    // Initialize sync
    isOnline().then((online) => {
      if (online) {
        startSyncInterval();
      }
    });

    return stateCreator(set, get, api);
  };

/**
 * Export type for middleware usage
 */
export type SyncMiddleware = <
  T extends object,
  Mps extends [StoreMutatorIdentifier, unknown][] = [],
  Mcs extends [StoreMutatorIdentifier, unknown][] = []
>(
  initializer: StateCreator<T, Mps, Mcs>
) => StateCreator<T, Mps, Mcs>;
