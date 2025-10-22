/**
 * Mood Selectors - Optimized subscriptions and derived state
 *
 * Provides memoized selectors for mood analytics and trends.
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { MoodSlice } from '../slices/moodSlice';
import { MoodEntry } from '../../types/schemas';

/**
 * Mood trends selector with analytics calculations
 */
export const selectMoodTrends = (state: MoodSlice) => {
  const { entries } = state;
  const now = new Date();
  const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  const weekEntries = entries.filter((e) => e.timestamp >= weekAgo);
  const monthEntries = entries.filter((e) => e.timestamp >= monthAgo);

  const calculateAverage = (items: MoodEntry[]) =>
    items.length > 0
      ? items.reduce((sum, e) => sum + e.mood_level, 0) / items.length
      : 0;

  const calculateDistribution = (items: MoodEntry[]) => {
    const dist = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    items.forEach((e) => {
      dist[e.mood_level as keyof typeof dist]++;
    });
    return dist;
  };

  return {
    weekAverage: calculateAverage(weekEntries),
    monthAverage: calculateAverage(monthEntries),
    weekDistribution: calculateDistribution(weekEntries),
    monthDistribution: calculateDistribution(monthEntries),
    totalEntries: entries.length,
    weekEntries: weekEntries.length,
    monthEntries: monthEntries.length,
  };
};

/**
 * Activity correlation selector
 */
export const selectActivityCorrelations = (state: MoodSlice) => {
  const { entries } = state;
  const activities: Record<string, { count: number; totalMood: number }> = {};

  entries.forEach((entry) => {
    entry.activities.forEach((activity) => {
      if (!activities[activity]) {
        activities[activity] = { count: 0, totalMood: 0 };
      }
      activities[activity].count++;
      activities[activity].totalMood += entry.mood_level;
    });
  });

  return Object.entries(activities).map(([activity, data]) => ({
    activity,
    averageMood: data.totalMood / data.count,
    frequency: data.count,
  }));
};
