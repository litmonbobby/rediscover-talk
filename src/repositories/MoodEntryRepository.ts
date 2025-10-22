/**
 * Mood Entry Repository
 *
 * Manages mood tracking data with offline-first persistence.
 * Implements repository pattern for mood entries with local storage and background sync.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 * @feature Wellness Logs (Mood Tracking)
 */

import { v4 as uuidv4 } from 'uuid';
import { BaseRepository } from './BaseRepository';
import { SyncService } from '../services/SyncService';
import { StorageService } from '../services/StorageService';
import {
  MoodEntry,
  CreateMoodEntryInput,
  MoodTrend,
  Schemas,
  validateSchemaOrThrow,
} from '../types/schemas';

export class MoodEntryRepository implements BaseRepository<MoodEntry, CreateMoodEntryInput, Partial<MoodEntry>> {
  private readonly STORAGE_KEY = '@rediscover_talk:mood_entries';
  private syncService: SyncService;
  private storageService: StorageService;

  constructor() {
    this.syncService = SyncService.getInstance();
    this.storageService = StorageService.getInstance();
  }

  /**
   * Create a new mood entry
   */
  async create(input: CreateMoodEntryInput): Promise<MoodEntry> {
    // Validate input
    validateSchemaOrThrow(Schemas.CreateMoodEntryInput, input);

    // Map mood level to emoji if not provided
    const moodEmoji = input.mood_emoji || this.getMoodEmoji(input.mood_level);

    const newEntry: MoodEntry = {
      id: uuidv4(),
      created_at: new Date(),
      updated_at: new Date(),
      synced_at: null,
      is_synced: false,
      mood_emoji: moodEmoji,
      ...input,
    };

    // Validate complete entry
    validateSchemaOrThrow(Schemas.MoodEntry, newEntry);

    // 1. Save locally immediately (instant UI feedback)
    const entries = await this.getAll();
    entries.unshift(newEntry); // Add to beginning (most recent first)
    await this.storageService.set(this.STORAGE_KEY, entries);

    // 2. Add to sync queue for background sync
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'create',
      data: newEntry,
    });

    return newEntry;
  }

  /**
   * Update an existing mood entry
   */
  async update(id: string, input: Partial<MoodEntry>): Promise<MoodEntry> {
    const entries = await this.getAll();
    const index = entries.findIndex(e => e.id === id);

    if (index === -1) {
      throw new Error(`Mood entry not found: ${id}`);
    }

    const updatedEntry: MoodEntry = {
      ...entries[index],
      ...input,
      updated_at: new Date(),
      is_synced: false, // Mark as unsynced
      synced_at: null,
    };

    // Validate updated entry
    validateSchemaOrThrow(Schemas.MoodEntry, updatedEntry);

    // 1. Update locally immediately
    entries[index] = updatedEntry;
    await this.storageService.set(this.STORAGE_KEY, entries);

    // 2. Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'update',
      data: updatedEntry,
    });

    return updatedEntry;
  }

  /**
   * Delete a mood entry
   */
  async delete(id: string): Promise<void> {
    const entries = await this.getAll();
    const entryToDelete = entries.find(e => e.id === id);

    if (!entryToDelete) {
      throw new Error(`Mood entry not found: ${id}`);
    }

    // 1. Delete locally immediately
    const updatedEntries = entries.filter(e => e.id !== id);
    await this.storageService.set(this.STORAGE_KEY, updatedEntries);

    // 2. Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'delete',
      data: { id },
    });
  }

  /**
   * Get mood entry by ID
   */
  async getById(id: string): Promise<MoodEntry | null> {
    const entries = await this.getAll();
    return entries.find(e => e.id === id) || null;
  }

  /**
   * Get all mood entries (sorted by timestamp descending)
   */
  async getAll(): Promise<MoodEntry[]> {
    const entries = await this.storageService.get<MoodEntry[]>(this.STORAGE_KEY);
    if (!entries) {
      return [];
    }

    // Sort by timestamp descending (most recent first)
    return entries.sort((a, b) =>
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    );
  }

  /**
   * Get mood entries for a specific date range
   */
  async getByDateRange(startDate: Date, endDate: Date): Promise<MoodEntry[]> {
    const entries = await this.getAll();
    return entries.filter(entry => {
      const timestamp = new Date(entry.timestamp);
      return timestamp >= startDate && timestamp <= endDate;
    });
  }

  /**
   * Get recent mood entries (last N entries)
   */
  async getRecent(limit: number = 10): Promise<MoodEntry[]> {
    const entries = await this.getAll();
    return entries.slice(0, limit);
  }

  /**
   * Calculate mood trend analytics
   */
  async getMoodTrend(period: 'week' | 'month' | 'quarter' | 'year'): Promise<MoodTrend> {
    const { startDate, endDate } = this.getPeriodDates(period);
    const entries = await this.getByDateRange(startDate, endDate);

    if (entries.length === 0) {
      return {
        average_mood: 0,
        mood_variance: 0,
        total_entries: 0,
        period,
        start_date: startDate,
        end_date: endDate,
        mood_distribution: {
          very_low: 0,
          low: 0,
          neutral: 0,
          good: 0,
          excellent: 0,
        },
      };
    }

    // Calculate average mood
    const totalMood = entries.reduce((sum, entry) => sum + entry.mood_level, 0);
    const average_mood = totalMood / entries.length;

    // Calculate variance
    const variance = entries.reduce((sum, entry) =>
      sum + Math.pow(entry.mood_level - average_mood, 2), 0
    ) / entries.length;

    // Calculate mood distribution
    const mood_distribution = {
      very_low: entries.filter(e => e.mood_level === 1).length,
      low: entries.filter(e => e.mood_level === 2).length,
      neutral: entries.filter(e => e.mood_level === 3).length,
      good: entries.filter(e => e.mood_level === 4).length,
      excellent: entries.filter(e => e.mood_level === 5).length,
    };

    // Calculate activity correlations
    const activity_correlations = this.calculateActivityCorrelations(entries);

    const trend: MoodTrend = {
      average_mood,
      mood_variance: variance,
      total_entries: entries.length,
      period,
      start_date: startDate,
      end_date: endDate,
      mood_distribution,
      activity_correlations,
    };

    // Validate trend data
    validateSchemaOrThrow(Schemas.MoodTrend, trend);

    return trend;
  }

  /**
   * Clear all mood entries (for user logout)
   */
  async clear(): Promise<void> {
    await this.storageService.remove(this.STORAGE_KEY);
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /**
   * Get emoji for mood level
   */
  private getMoodEmoji(moodLevel: number): '😔' | '😕' | '😐' | '🙂' | '😊' {
    const emojiMap: Record<number, '😔' | '😕' | '😐' | '🙂' | '😊'> = {
      1: '😔',
      2: '😕',
      3: '😐',
      4: '🙂',
      5: '😊',
    };
    return emojiMap[moodLevel] || '😐';
  }

  /**
   * Get start and end dates for analytics period
   */
  private getPeriodDates(period: 'week' | 'month' | 'quarter' | 'year'): { startDate: Date; endDate: Date } {
    const endDate = new Date();
    const startDate = new Date();

    switch (period) {
      case 'week':
        startDate.setDate(endDate.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(endDate.getMonth() - 1);
        break;
      case 'quarter':
        startDate.setMonth(endDate.getMonth() - 3);
        break;
      case 'year':
        startDate.setFullYear(endDate.getFullYear() - 1);
        break;
    }

    return { startDate, endDate };
  }

  /**
   * Calculate correlations between activities and mood levels
   */
  private calculateActivityCorrelations(entries: MoodEntry[]): Array<{ activity: string; correlation_score: number }> {
    // Collect all unique activities
    const allActivities = new Set<string>();
    entries.forEach(entry => {
      entry.activities.forEach(activity => allActivities.add(activity));
    });

    // Calculate average mood for each activity
    const correlations: Array<{ activity: string; correlation_score: number }> = [];

    allActivities.forEach(activity => {
      const entriesWithActivity = entries.filter(e => e.activities.includes(activity));
      const entriesWithoutActivity = entries.filter(e => !e.activities.includes(activity));

      if (entriesWithActivity.length === 0) return;

      const avgMoodWith = entriesWithActivity.reduce((sum, e) => sum + e.mood_level, 0) / entriesWithActivity.length;
      const avgMoodWithout = entriesWithoutActivity.length > 0
        ? entriesWithoutActivity.reduce((sum, e) => sum + e.mood_level, 0) / entriesWithoutActivity.length
        : avgMoodWith;

      // Simple correlation: positive if mood higher with activity
      const correlation_score = (avgMoodWith - avgMoodWithout) / 5; // Normalize to -1 to 1

      correlations.push({
        activity,
        correlation_score: Math.max(-1, Math.min(1, correlation_score)), // Clamp to [-1, 1]
      });
    });

    // Sort by correlation score descending
    return correlations.sort((a, b) => b.correlation_score - a.correlation_score);
  }
}
