/**
 * Base Repository Interface
 *
 * Generic repository pattern interface for all data entities.
 * Provides consistent API for CRUD operations with offline-first architecture.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 * @pattern Repository Pattern with Local-First Architecture
 */

export interface BaseRepository<
  TEntity,
  TCreateInput,
  TUpdateInput = Partial<TEntity>
> {
  /**
   * Create a new entity
   * - Saves locally immediately (optimistic UI)
   * - Adds to sync queue for background sync
   * @param input Entity creation data
   * @returns Created entity with local ID
   */
  create(input: TCreateInput): Promise<TEntity>;

  /**
   * Update an existing entity
   * - Updates local storage immediately
   * - Adds to sync queue for background sync
   * @param id Entity ID
   * @param input Partial entity data to update
   * @returns Updated entity
   */
  update(id: string, input: TUpdateInput): Promise<TEntity>;

  /**
   * Delete an entity
   * - Removes from local storage immediately
   * - Adds to sync queue for background sync
   * @param id Entity ID
   */
  delete(id: string): Promise<void>;

  /**
   * Get entity by ID
   * - Fetches from local storage (fast)
   * - No network request
   * @param id Entity ID
   * @returns Entity or null if not found
   */
  getById(id: string): Promise<TEntity | null>;

  /**
   * Get all entities
   * - Fetches from local storage (fast)
   * - Background sync may update data
   * @returns Array of all entities
   */
  getAll(): Promise<TEntity[]>;

  /**
   * Clear all entities from local storage
   * - WARNING: This is destructive
   * - Used for user logout or data reset
   */
  clear(): Promise<void>;
}
