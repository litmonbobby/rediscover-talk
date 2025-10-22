/**
 * Exercises Selectors - Progress tracking
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { ExercisesSlice } from '../slices/exercisesSlice';

/**
 * Exercise progress and statistics
 */
export const selectExerciseProgress = (state: ExercisesSlice) => {
  const { completions } = state;
  const now = new Date();
  const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  const recentCompletions = completions.filter(
    (c) => c.completion_date >= monthAgo
  );

  const uniqueExercises = new Set(completions.map((c) => c.exercise_id)).size;

  const totalParticipants = completions.reduce(
    (sum, c) => sum + c.participants.length,
    0
  );

  const avgEnjoyment =
    completions.filter((c) => c.enjoyment_rating !== null).length > 0
      ? completions.reduce((sum, c) => sum + (c.enjoyment_rating || 0), 0) /
        completions.filter((c) => c.enjoyment_rating !== null).length
      : 0;

  return {
    totalCompletions: completions.length,
    recentCompletions: recentCompletions.length,
    uniqueExercises,
    averageEnjoyment: avgEnjoyment,
    totalParticipants,
    averageParticipantsPerSession:
      completions.length > 0 ? totalParticipants / completions.length : 0,
  };
};
