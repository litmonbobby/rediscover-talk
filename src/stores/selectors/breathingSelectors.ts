/**
 * Breathing Selectors - Session analytics
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { BreathingSlice } from '../slices/breathingSlice';

/**
 * Breathing session statistics and improvements
 */
export const selectBreathingStats = (state: BreathingSlice) => {
  const { sessions } = state;

  const completedSessions = sessions.filter((s) => s.completed_cycles > 0);

  const avgMoodImprovement =
    completedSessions.filter(
      (s) => s.mood_before !== null && s.mood_after !== null
    ).length > 0
      ? completedSessions.reduce(
          (sum, s) =>
            sum +
            ((s.mood_after || 0) - (s.mood_before || 0)),
          0
        ) /
        completedSessions.filter(
          (s) => s.mood_before !== null && s.mood_after !== null
        ).length
      : 0;

  const avgAnxietyReduction =
    completedSessions.filter(
      (s) => s.anxiety_before !== null && s.anxiety_after !== null
    ).length > 0
      ? completedSessions.reduce(
          (sum, s) =>
            sum +
            ((s.anxiety_before || 0) - (s.anxiety_after || 0)),
          0
        ) /
        completedSessions.filter(
          (s) => s.anxiety_before !== null && s.anxiety_after !== null
        ).length
      : 0;

  const totalMinutes = Math.round(
    completedSessions.reduce((sum, s) => sum + s.duration_seconds, 0) / 60
  );

  return {
    totalSessions: completedSessions.length,
    totalMinutes,
    averageMoodImprovement: avgMoodImprovement,
    averageAnxietyReduction: avgAnxietyReduction,
    streak: state.breathingStreak,
  };
};
