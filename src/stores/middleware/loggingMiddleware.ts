/**
 * Logging Middleware - State change tracking for debugging
 *
 * Logs all state mutations in development mode.
 * Helps track data flow and identify state inconsistencies.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { StateCreator, StoreMutatorIdentifier } from 'zustand';

/**
 * Logging configuration
 */
export interface LoggingConfig {
  enabled: boolean;
  logActions: boolean;
  logStateChanges: boolean;
  collapseGroups: boolean;
  filter?: (action: string) => boolean;
}

/**
 * Default logging configuration
 */
const defaultConfig: LoggingConfig = {
  enabled: __DEV__, // Only in development
  logActions: true,
  logStateChanges: true,
  collapseGroups: true,
};

/**
 * Logging middleware creator
 *
 * Usage:
 * ```typescript
 * create(
 *   loggingMiddleware(
 *     (...a) => ({ ...slices }),
 *     { collapseGroups: false }
 *   )
 * )
 * ```
 */
export const createLoggingMiddleware =
  <T extends object>(config: Partial<LoggingConfig> = {}) =>
  (stateCreator: StateCreator<T>): StateCreator<T> =>
  (set, get, api) => {
    const loggingConfig = { ...defaultConfig, ...config };

    if (!loggingConfig.enabled) {
      return stateCreator(set, get, api);
    }

    /**
     * Wrapped set function with logging
     */
    const wrappedSet: typeof set = (...args) => {
      const prevState = get();

      // Call original set
      set(...args);

      const nextState = get();

      // Log state change
      if (loggingConfig.logStateChanges) {
        logStateChange(prevState, nextState);
      }
    };

    /**
     * Log state change with diff
     */
    const logStateChange = (prevState: T, nextState: T) => {
      const timestamp = new Date().toISOString();
      const diff = getStateDiff(prevState, nextState);

      if (Object.keys(diff).length === 0) return; // No changes

      const groupLabel = `[Zustand] State Update @ ${timestamp}`;

      if (loggingConfig.collapseGroups && console.groupCollapsed) {
        console.groupCollapsed(groupLabel);
      } else if (console.group) {
        console.group(groupLabel);
      }

      console.log('%cPrevious State:', 'color: #9E9E9E; font-weight: bold', prevState);
      console.log('%cChanges:', 'color: #03A9F4; font-weight: bold', diff);
      console.log('%cNext State:', 'color: #4CAF50; font-weight: bold', nextState);

      if (console.groupEnd) {
        console.groupEnd();
      }
    };

    /**
     * Get state diff (shallow comparison)
     */
    const getStateDiff = (prev: T, next: T): Partial<T> => {
      const diff: Partial<T> = {};

      Object.keys(next).forEach((key) => {
        const typedKey = key as keyof T;
        if (prev[typedKey] !== next[typedKey]) {
          diff[typedKey] = next[typedKey];
        }
      });

      return diff;
    };

    return stateCreator(wrappedSet, get, api);
  };

/**
 * Export type for middleware usage
 */
export type LoggingMiddleware = <
  T extends object,
  Mps extends [StoreMutatorIdentifier, unknown][] = [],
  Mcs extends [StoreMutatorIdentifier, unknown][] = []
>(
  initializer: StateCreator<T, Mps, Mcs>
) => StateCreator<T, Mps, Mcs>;
