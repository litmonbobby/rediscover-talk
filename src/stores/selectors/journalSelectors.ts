/**
 * Journal Selectors - Search and filtering
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 */

import { JournalSlice, JournalMetadata } from '../slices/journalSlice';

/**
 * Journal search results with relevance scoring
 */
export const selectJournalSearchResults = (state: JournalSlice) => {
  const { journalMetadata, searchFilters } = state;
  let results = [...journalMetadata];

  // Apply all filters (implemented in journalSlice selectFilteredJournals)
  // This is a lightweight wrapper for computed search results

  if (searchFilters.query.trim()) {
    const query = searchFilters.query.toLowerCase();
    results = results.filter((j) => j.title.toLowerCase().includes(query));
  }

  if (searchFilters.tags.length > 0) {
    results = results.filter((j) =>
      searchFilters.tags.some((tag) => j.tags.includes(tag))
    );
  }

  return results.map((journal) => ({
    ...journal,
    relevanceScore: calculateRelevance(journal, searchFilters.query),
  }));
};

/**
 * Calculate relevance score for search ranking
 */
function calculateRelevance(journal: JournalMetadata, query: string): number {
  if (!query.trim()) return 1;

  const queryLower = query.toLowerCase();
  const titleLower = journal.title.toLowerCase();

  let score = 0;

  // Exact title match
  if (titleLower === queryLower) score += 100;

  // Title contains query
  if (titleLower.includes(queryLower)) score += 50;

  // Tag match
  const tagMatch = journal.tags.some((tag) =>
    tag.toLowerCase().includes(queryLower)
  );
  if (tagMatch) score += 25;

  // Recency boost (newer entries ranked higher)
  const daysSinceCreated =
    (Date.now() - journal.created_at.getTime()) / (1000 * 60 * 60 * 24);
  score += Math.max(0, 10 - daysSinceCreated / 30);

  return score;
}
