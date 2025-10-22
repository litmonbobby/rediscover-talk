/**
 * Data Schemas for Rediscover Talk
 *
 * TypeScript interfaces and Zod validation schemas for all data models.
 * Provides type safety and runtime validation for:
 * - User data
 * - Conversation prompts and responses
 * - Wellness logs (mood entries)
 * - Therapeutic journal entries
 * - Family exercises and completions
 * - Crisis plan
 * - Analytics data
 *
 * @framework LitmonCloud Mobile Development Framework v3.1
 * @architecture MVVM with offline-first data persistence
 * @validation Zod runtime validation + TypeScript compile-time checks
 */

import { z } from 'zod';

// ============================================================================
// Base Schemas
// ============================================================================

/**
 * Base timestamp fields for all entities
 */
export const BaseTimestampsSchema = z.object({
  created_at: z.coerce.date(),
  updated_at: z.coerce.date(),
  synced_at: z.coerce.date().nullable(),
  is_synced: z.boolean(),
});

export type BaseTimestamps = z.infer<typeof BaseTimestampsSchema>;

/**
 * UUID validation
 */
export const UUIDSchema = z.string().uuid();

// ============================================================================
// User & Authentication Schemas
// ============================================================================

/**
 * User Profile
 */
export const UserProfileSchema = z.object({
  id: UUIDSchema,
  email: z.string().email().nullable(),
  display_name: z.string().min(1).max(100).nullable(),
  avatar_url: z.string().url().nullable(),
  preferences: z.object({
    notifications_enabled: z.boolean(),
    daily_reminder_time: z.string().nullable(), // HH:MM format
    theme: z.enum(['light', 'dark', 'system']),
    language: z.enum(['en', 'es', 'fr']),
  }),
  is_anonymous: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type UserProfile = z.infer<typeof UserProfileSchema>;

/**
 * Authentication tokens (stored in Keychain)
 */
export const AuthTokensSchema = z.object({
  access_token: z.string(),
  refresh_token: z.string(),
  expires_at: z.coerce.date(),
});

export type AuthTokens = z.infer<typeof AuthTokensSchema>;

// ============================================================================
// Conversation Prompts Schemas
// ============================================================================

/**
 * Daily conversation prompt
 */
export const ConversationPromptSchema = z.object({
  id: UUIDSchema,
  category: z.enum([
    'gratitude',
    'reflection',
    'connection',
    'growth',
    'mindfulness',
    'creativity',
  ]),
  prompt_text: z.string().min(10).max(500),
  follow_up_questions: z.array(z.string()).optional(),
  difficulty_level: z.enum(['easy', 'medium', 'hard']),
  is_active: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type ConversationPrompt = z.infer<typeof ConversationPromptSchema>;

/**
 * User response to conversation prompt
 */
export const PromptResponseSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  prompt_id: UUIDSchema,
  response_text: z.string().min(1).max(5000),
  shared_with_family: z.boolean(),
  reflection_notes: z.string().max(1000).nullable(),
  completion_time_seconds: z.number().int().positive().nullable(),
  ...BaseTimestampsSchema.shape,
});

export type PromptResponse = z.infer<typeof PromptResponseSchema>;

/**
 * Create prompt response input (for repository create method)
 */
export const CreatePromptResponseInputSchema = PromptResponseSchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreatePromptResponseInput = z.infer<typeof CreatePromptResponseInputSchema>;

// ============================================================================
// Wellness Logs (Mood Tracking) Schemas
// ============================================================================

/**
 * Mood entry with activities and notes
 */
export const MoodEntrySchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  mood_level: z.number().int().min(1).max(5), // 1=Very Low, 5=Very High
  mood_emoji: z.enum(['😔', '😕', '😐', '🙂', '😊']).nullable(),
  notes: z.string().max(500).nullable(),
  activities: z.array(z.enum([
    'exercise',
    'meditation',
    'journaling',
    'social',
    'work',
    'sleep',
    'hobbies',
    'therapy',
    'medication',
    'family_time',
  ])).default([]),
  energy_level: z.number().int().min(1).max(5).nullable(),
  sleep_quality: z.number().int().min(1).max(5).nullable(),
  stress_level: z.number().int().min(1).max(5).nullable(),
  timestamp: z.coerce.date(),
  ...BaseTimestampsSchema.shape,
});

export type MoodEntry = z.infer<typeof MoodEntrySchema>;

/**
 * Create mood entry input
 */
export const CreateMoodEntryInputSchema = MoodEntrySchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreateMoodEntryInput = z.infer<typeof CreateMoodEntryInputSchema>;

/**
 * Mood trend analytics
 */
export const MoodTrendSchema = z.object({
  average_mood: z.number().min(1).max(5),
  mood_variance: z.number().nonnegative(),
  total_entries: z.number().int().nonnegative(),
  period: z.enum(['week', 'month', 'quarter', 'year']),
  start_date: z.coerce.date(),
  end_date: z.coerce.date(),
  mood_distribution: z.object({
    very_low: z.number().int().nonnegative(), // Level 1
    low: z.number().int().nonnegative(),      // Level 2
    neutral: z.number().int().nonnegative(),   // Level 3
    good: z.number().int().nonnegative(),      // Level 4
    excellent: z.number().int().nonnegative(), // Level 5
  }),
  activity_correlations: z.array(z.object({
    activity: z.string(),
    correlation_score: z.number().min(-1).max(1),
  })).optional(),
});

export type MoodTrend = z.infer<typeof MoodTrendSchema>;

// ============================================================================
// Therapeutic Journal Schemas
// ============================================================================

/**
 * Journal entry (encrypted content)
 */
export const JournalEntrySchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  title: z.string().min(1).max(200),
  encrypted_content: z.string(), // AES-256 encrypted content
  mood_at_writing: z.number().int().min(1).max(5).nullable(),
  tags: z.array(z.string()).default([]),
  is_favorite: z.boolean().default(false),
  word_count: z.number().int().nonnegative(),
  prompt_id: UUIDSchema.nullable(), // Link to conversation prompt if inspired by one
  ...BaseTimestampsSchema.shape,
});

export type JournalEntry = z.infer<typeof JournalEntrySchema>;

/**
 * Create journal entry input
 */
export const CreateJournalEntryInputSchema = JournalEntrySchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreateJournalEntryInput = z.infer<typeof CreateJournalEntryInputSchema>;

/**
 * Journal entry with decrypted content (for UI display)
 */
export const DecryptedJournalEntrySchema = JournalEntrySchema.extend({
  content: z.string(), // Decrypted plaintext content
});

export type DecryptedJournalEntry = z.infer<typeof DecryptedJournalEntrySchema>;

// ============================================================================
// Family Exercises Schemas
// ============================================================================

/**
 * Family exercise from library
 */
export const FamilyExerciseSchema = z.object({
  id: UUIDSchema,
  title: z.string().min(1).max(200),
  description: z.string().min(1).max(1000),
  category: z.enum([
    'communication',
    'bonding',
    'conflict_resolution',
    'gratitude',
    'teamwork',
    'creativity',
    'mindfulness',
  ]),
  duration_minutes: z.number().int().positive(),
  recommended_age_min: z.number().int().positive().nullable(),
  recommended_age_max: z.number().int().positive().nullable(),
  participants_min: z.number().int().positive(),
  participants_max: z.number().int().positive().nullable(),
  difficulty_level: z.enum(['easy', 'medium', 'hard']),
  instructions: z.array(z.string()),
  materials_needed: z.array(z.string()).default([]),
  learning_outcomes: z.array(z.string()).default([]),
  is_active: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type FamilyExercise = z.infer<typeof FamilyExerciseSchema>;

/**
 * Exercise completion by user
 */
export const ExerciseCompletionSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  exercise_id: UUIDSchema,
  participants: z.array(z.object({
    name: z.string().min(1).max(100),
    age: z.number().int().positive().nullable(),
    relationship: z.string().max(50).nullable(),
  })),
  duration_minutes: z.number().int().positive(),
  enjoyment_rating: z.number().int().min(1).max(5).nullable(),
  difficulty_rating: z.number().int().min(1).max(5).nullable(),
  notes: z.string().max(1000).nullable(),
  would_repeat: z.boolean().nullable(),
  completion_date: z.coerce.date(),
  ...BaseTimestampsSchema.shape,
});

export type ExerciseCompletion = z.infer<typeof ExerciseCompletionSchema>;

/**
 * Create exercise completion input
 */
export const CreateExerciseCompletionInputSchema = ExerciseCompletionSchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreateExerciseCompletionInput = z.infer<typeof CreateExerciseCompletionInputSchema>;

// ============================================================================
// Crisis Plan Schemas
// ============================================================================

/**
 * Crisis plan (encrypted sensitive data)
 */
export const CrisisPlanSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  encrypted_warning_signs: z.string(), // Encrypted JSON array
  encrypted_coping_strategies: z.string(), // Encrypted JSON array
  encrypted_reasons_to_live: z.string(), // Encrypted JSON array
  encrypted_support_contacts: z.string(), // Encrypted JSON array with {name, phone, relationship}
  encrypted_professional_contacts: z.string(), // Encrypted JSON array with {name, phone, role}
  encrypted_safe_environments: z.string(), // Encrypted JSON array with {location, why_safe}
  emergency_instructions: z.string().max(2000).nullable(),
  last_reviewed_at: z.coerce.date().nullable(),
  ...BaseTimestampsSchema.shape,
});

export type CrisisPlan = z.infer<typeof CrisisPlanSchema>;

/**
 * Decrypted crisis plan (for UI display)
 */
export const DecryptedCrisisPlanSchema = CrisisPlanSchema.extend({
  warning_signs: z.array(z.string()),
  coping_strategies: z.array(z.string()),
  reasons_to_live: z.array(z.string()),
  support_contacts: z.array(z.object({
    name: z.string(),
    phone: z.string(),
    relationship: z.string(),
  })),
  professional_contacts: z.array(z.object({
    name: z.string(),
    phone: z.string(),
    role: z.string(),
  })),
  safe_environments: z.array(z.object({
    location: z.string(),
    why_safe: z.string(),
  })),
});

export type DecryptedCrisisPlan = z.infer<typeof DecryptedCrisisPlanSchema>;

/**
 * Emergency resource (hotlines, clinics)
 */
export const EmergencyResourceSchema = z.object({
  id: UUIDSchema,
  name: z.string().min(1).max(200),
  type: z.enum(['hotline', 'crisis_center', 'clinic', 'hospital', 'online_resource']),
  phone: z.string().nullable(),
  website: z.string().url().nullable(),
  address: z.string().max(500).nullable(),
  description: z.string().max(1000),
  availability: z.string().max(200), // e.g., "24/7", "Mon-Fri 9am-5pm"
  languages: z.array(z.string()).default(['en']),
  is_free: z.boolean(),
  country_code: z.string().length(2), // ISO 3166-1 alpha-2
  region: z.string().max(100).nullable(),
  is_active: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type EmergencyResource = z.infer<typeof EmergencyResourceSchema>;

// ============================================================================
// Analytics Schemas
// ============================================================================

/**
 * User insights and analytics
 */
export const UserInsightsSchema = z.object({
  user_id: UUIDSchema,
  period: z.enum(['week', 'month', 'quarter', 'year']),
  start_date: z.coerce.date(),
  end_date: z.coerce.date(),

  // Mood analytics
  mood_trend: MoodTrendSchema,

  // Activity analytics
  total_journal_entries: z.number().int().nonnegative(),
  total_prompt_responses: z.number().int().nonnegative(),
  total_exercises_completed: z.number().int().nonnegative(),
  active_days: z.number().int().nonnegative(),
  longest_streak: z.number().int().nonnegative(),
  current_streak: z.number().int().nonnegative(),

  // Engagement metrics
  average_session_duration_minutes: z.number().nonnegative(),
  total_time_spent_minutes: z.number().nonnegative(),

  // Recommendations
  recommended_exercises: z.array(UUIDSchema).default([]),
  recommended_prompts: z.array(UUIDSchema).default([]),

  generated_at: z.coerce.date(),
});

export type UserInsights = z.infer<typeof UserInsightsSchema>;

// ============================================================================
// Breathing Exercise Schemas
// ============================================================================

/**
 * Breathing exercise preset
 */
export const BreathingExerciseSchema = z.object({
  id: UUIDSchema,
  name: z.string().min(1).max(100),
  description: z.string().max(500),
  technique: z.enum([
    'box_breathing',      // 4-4-4-4 (inhale-hold-exhale-hold)
    'diaphragmatic',      // Deep belly breathing
    '4_7_8',              // 4-7-8 (inhale-hold-exhale)
    'alternate_nostril',  // Nadi Shodhana
    'resonant',           // 5-5 (inhale-exhale)
  ]),
  inhale_seconds: z.number().int().positive(),
  hold_seconds: z.number().int().nonnegative(),
  exhale_seconds: z.number().int().positive(),
  hold_exhale_seconds: z.number().int().nonnegative().default(0),
  cycles: z.number().int().positive(),
  total_duration_seconds: z.number().int().positive(),
  difficulty_level: z.enum(['beginner', 'intermediate', 'advanced']),
  benefits: z.array(z.string()).default([]),
  contraindications: z.array(z.string()).default([]),
  is_active: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type BreathingExercise = z.infer<typeof BreathingExerciseSchema>;

/**
 * Breathing session completion
 */
export const BreathingSessionSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  exercise_id: UUIDSchema,
  completed_cycles: z.number().int().nonnegative(),
  duration_seconds: z.number().int().positive(),
  mood_before: z.number().int().min(1).max(5).nullable(),
  mood_after: z.number().int().min(1).max(5).nullable(),
  anxiety_before: z.number().int().min(1).max(5).nullable(),
  anxiety_after: z.number().int().min(1).max(5).nullable(),
  notes: z.string().max(500).nullable(),
  completion_date: z.coerce.date(),
  ...BaseTimestampsSchema.shape,
});

export type BreathingSession = z.infer<typeof BreathingSessionSchema>;

/**
 * Create breathing session input
 */
export const CreateBreathingSessionInputSchema = BreathingSessionSchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreateBreathingSessionInput = z.infer<typeof CreateBreathingSessionInputSchema>;

// ============================================================================
// Meditation Library Schemas
// ============================================================================

/**
 * Guided meditation audio
 */
export const MeditationSchema = z.object({
  id: UUIDSchema,
  title: z.string().min(1).max(200),
  description: z.string().max(1000),
  instructor: z.string().max(100).nullable(),
  duration_minutes: z.number().int().positive(),
  category: z.enum([
    'mindfulness',
    'body_scan',
    'loving_kindness',
    'sleep',
    'anxiety_relief',
    'stress_reduction',
    'focus',
    'gratitude',
  ]),
  difficulty_level: z.enum(['beginner', 'intermediate', 'advanced']),
  audio_url: z.string().url(),
  transcript_url: z.string().url().nullable(),
  thumbnail_url: z.string().url().nullable(),
  background_music: z.boolean(),
  voice_gender: z.enum(['male', 'female', 'neutral']).nullable(),
  tags: z.array(z.string()).default([]),
  is_premium: z.boolean(),
  is_active: z.boolean(),
  ...BaseTimestampsSchema.shape,
});

export type Meditation = z.infer<typeof MeditationSchema>;

/**
 * Meditation session completion
 */
export const MeditationSessionSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  meditation_id: UUIDSchema,
  completed: z.boolean(), // True if user finished full session
  duration_seconds: z.number().int().positive(),
  mood_before: z.number().int().min(1).max(5).nullable(),
  mood_after: z.number().int().min(1).max(5).nullable(),
  focus_rating: z.number().int().min(1).max(5).nullable(),
  notes: z.string().max(500).nullable(),
  completion_date: z.coerce.date(),
  ...BaseTimestampsSchema.shape,
});

export type MeditationSession = z.infer<typeof MeditationSessionSchema>;

/**
 * Create meditation session input
 */
export const CreateMeditationSessionInputSchema = MeditationSessionSchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true,
});

export type CreateMeditationSessionInput = z.infer<typeof CreateMeditationSessionInputSchema>;

// ============================================================================
// AI Guide Schemas (Optional Future Feature)
// ============================================================================

/**
 * AI chat message
 */
export const AIChatMessageSchema = z.object({
  id: UUIDSchema,
  user_id: UUIDSchema,
  role: z.enum(['user', 'assistant']),
  content: z.string().min(1).max(5000),
  context: z.object({
    mood_level: z.number().int().min(1).max(5).nullable(),
    recent_activities: z.array(z.string()).nullable(),
    crisis_detected: z.boolean().default(false),
  }).nullable(),
  timestamp: z.coerce.date(),
  ...BaseTimestampsSchema.shape,
});

export type AIChatMessage = z.infer<typeof AIChatMessageSchema>;

// ============================================================================
// Sync Queue Schemas
// ============================================================================

/**
 * Sync queue item for background synchronization
 */
export const SyncQueueItemSchema = z.object({
  id: z.string(),
  type: z.enum([
    'mood_entry',
    'journal_entry',
    'prompt_response',
    'exercise_completion',
    'crisis_plan',
    'breathing_session',
    'meditation_session',
    'user_profile',
  ]),
  operation: z.enum(['create', 'update', 'delete']),
  data: z.any(), // Payload specific to entity type
  attempts: z.number().int().nonnegative(),
  lastAttempt: z.coerce.date().nullable(),
  createdAt: z.coerce.date(),
  error: z.string().nullable(),
});

export type SyncQueueItem = z.infer<typeof SyncQueueItemSchema>;

// ============================================================================
// Validation Helpers
// ============================================================================

/**
 * Validate data against schema with detailed error messages
 */
export function validateSchema<T>(schema: z.ZodSchema<T>, data: unknown): { success: true; data: T } | { success: false; errors: string[] } {
  const result = schema.safeParse(data);

  if (result.success) {
    return { success: true, data: result.data };
  }

  const errors = result.error.errors.map(err =>
    `${err.path.join('.')}: ${err.message}`
  );

  return { success: false, errors };
}

/**
 * Validate and throw on error
 */
export function validateSchemaOrThrow<T>(schema: z.ZodSchema<T>, data: unknown): T {
  return schema.parse(data);
}

// ============================================================================
// Export All Schemas
// ============================================================================

export const Schemas = {
  // Base
  BaseTimestamps: BaseTimestampsSchema,
  UUID: UUIDSchema,

  // User & Auth
  UserProfile: UserProfileSchema,
  AuthTokens: AuthTokensSchema,

  // Conversation Prompts
  ConversationPrompt: ConversationPromptSchema,
  PromptResponse: PromptResponseSchema,
  CreatePromptResponseInput: CreatePromptResponseInputSchema,

  // Wellness Logs
  MoodEntry: MoodEntrySchema,
  CreateMoodEntryInput: CreateMoodEntryInputSchema,
  MoodTrend: MoodTrendSchema,

  // Journal
  JournalEntry: JournalEntrySchema,
  CreateJournalEntryInput: CreateJournalEntryInputSchema,
  DecryptedJournalEntry: DecryptedJournalEntrySchema,

  // Family Exercises
  FamilyExercise: FamilyExerciseSchema,
  ExerciseCompletion: ExerciseCompletionSchema,
  CreateExerciseCompletionInput: CreateExerciseCompletionInputSchema,

  // Crisis Plan
  CrisisPlan: CrisisPlanSchema,
  DecryptedCrisisPlan: DecryptedCrisisPlanSchema,
  EmergencyResource: EmergencyResourceSchema,

  // Analytics
  UserInsights: UserInsightsSchema,

  // Breathing
  BreathingExercise: BreathingExerciseSchema,
  BreathingSession: BreathingSessionSchema,
  CreateBreathingSessionInput: CreateBreathingSessionInputSchema,

  // Meditation
  Meditation: MeditationSchema,
  MeditationSession: MeditationSessionSchema,
  CreateMeditationSessionInput: CreateMeditationSessionInputSchema,

  // AI Guide
  AIChatMessage: AIChatMessageSchema,

  // Sync
  SyncQueueItem: SyncQueueItemSchema,
};
