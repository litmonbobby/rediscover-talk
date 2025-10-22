# Rediscover Talk - Backend Integration Architecture

**Version**: 1.0.0
**Platform**: React Native (iOS + Android)
**Framework**: LitmonCloud Mobile Development Framework v3.1
**Architecture**: Offline-First with Background Sync
**Backend**: Supabase (PostgreSQL + Realtime + Storage)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Backend Platform Selection](#backend-platform-selection)
3. [API Architecture](#api-architecture)
4. [Data Synchronization Strategy](#data-synchronization-strategy)
5. [Authentication & Authorization](#authentication--authorization)
6. [Data Models & Schemas](#data-models--schemas)
7. [Repository Pattern](#repository-pattern)
8. [Network Configuration](#network-configuration)
9. [Offline Functionality](#offline-functionality)
10. [Real-time Features](#real-time-features)
11. [Security & Privacy](#security--privacy)
12. [Testing Strategy](#testing-strategy)

---

## Executive Summary

Rediscover Talk implements an **offline-first architecture** with **Supabase as the backend platform**. All features work without network connectivity, with background synchronization when online. This document defines API contracts, sync strategies, data models, and security patterns.

**Key Architectural Decisions**:
- **Backend Platform**: Supabase (ADR-004)
- **Sync Strategy**: Background queue with conflict resolution (ADR-005)
- **Auth**: Sign in with Apple + JWT tokens
- **Privacy**: End-to-end encryption for sensitive data
- **Real-time**: Optional for family exercises (not MVP)

**Success Metrics**:
- 100% offline functionality for core features
- <200ms API response time (95th percentile)
- <5s background sync time for typical user data
- Zero data loss during sync conflicts
- HIPAA-compliant data handling

---

## Backend Platform Selection

### Decision: Supabase (PostgreSQL + Realtime + Storage)

**Rationale** (see ADR-004 for full details):
- ✅ PostgreSQL: Robust relational database with JSON support
- ✅ Row Level Security (RLS): Built-in authorization at database level
- ✅ Realtime: WebSocket subscriptions for live updates (optional)
- ✅ Storage: File storage for journal attachments (future)
- ✅ Auth: Sign in with Apple, email/password, JWT tokens
- ✅ Edge Functions: Serverless backend logic (Deno runtime)
- ✅ Free tier: Generous limits for MVP
- ✅ Open Source: Self-hostable, no vendor lock-in

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                     Mobile App (React Native)                │
│  ┌────────────┐  ┌────────────┐  ┌─────────────────┐        │
│  │   Local    │  │   Sync     │  │   Network       │        │
│  │  Database  │◄─┤   Queue    │◄─┤   Service       │        │
│  │ AsyncStore │  │ Background │  │ (Supabase SDK)  │        │
│  └────────────┘  └────────────┘  └─────────────────┘        │
└──────────────────────────────────┬───────────────────────────┘
                                   │ HTTPS/TLS 1.3
                                   │ JWT Authentication
                                   │ Certificate Pinning
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                    Supabase Backend                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ PostgreSQL │  │  Realtime  │  │   Edge     │            │
│  │ + RLS      │  │ WebSockets │  │ Functions  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│  ┌────────────┐  ┌────────────┐                             │
│  │  Storage   │  │    Auth    │                             │
│  │  (Files)   │  │   (JWT)    │                             │
│  └────────────┘  └────────────┘                             │
└──────────────────────────────────────────────────────────────┘
```

---

## API Architecture

### RESTful API Endpoints

All endpoints use Supabase PostgreSQL REST API with automatic OpenAPI generation.

#### Authentication Endpoints

**Sign in with Apple**
```typescript
POST /auth/v1/signup
Content-Type: application/json

{
  "provider": "apple",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}

Response 200:
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "v1.MeHPpSVoGIx...",
  "expires_in": 3600,
  "token_type": "bearer",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@privaterelay.appleid.com",
    "created_at": "2025-10-21T12:00:00Z"
  }
}
```

**Anonymous Sign-in** (for trying app before commitment)
```typescript
POST /auth/v1/signup
Content-Type: application/json

{
  "is_anonymous": true
}

Response 200:
{
  "access_token": "...",
  "user": {
    "id": "...",
    "is_anonymous": true
  }
}
```

**Refresh Token**
```typescript
POST /auth/v1/token?grant_type=refresh_token
Content-Type: application/json

{
  "refresh_token": "v1.MeHPpSVoGIx..."
}

Response 200:
{
  "access_token": "...",
  "expires_in": 3600
}
```

#### Conversation Prompts

**Fetch Daily Prompt**
```typescript
GET /rest/v1/conversation_prompts?date=eq.2025-10-21&select=*
Authorization: Bearer {access_token}

Response 200:
{
  "id": "prompt-uuid",
  "category": "family",
  "question": "What's a favorite memory from this week?",
  "follow_up_questions": ["Why was it special?", "Who was involved?"],
  "created_at": "2025-10-21T00:00:00Z"
}
```

**Submit Prompt Response**
```typescript
POST /rest/v1/prompt_responses
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "prompt_id": "prompt-uuid",
  "user_id": "user-uuid",
  "response_text": "We had a great family dinner...",
  "completed_at": "2025-10-21T19:30:00Z"
}

Response 201:
{
  "id": "response-uuid",
  "prompt_id": "prompt-uuid",
  "user_id": "user-uuid",
  "response_text": "We had a great family dinner...",
  "completed_at": "2025-10-21T19:30:00Z",
  "created_at": "2025-10-21T19:30:00Z"
}
```

#### Wellness Logs & Mood Tracking

**Create Mood Entry**
```typescript
POST /rest/v1/mood_entries
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "user_id": "user-uuid",
  "mood_level": 4,
  "notes": "Feeling energized after morning walk",
  "activities": ["exercise", "meditation"],
  "timestamp": "2025-10-21T08:00:00Z"
}

Response 201:
{
  "id": "mood-uuid",
  "user_id": "user-uuid",
  "mood_level": 4,
  "notes": "Feeling energized after morning walk",
  "activities": ["exercise", "meditation"],
  "timestamp": "2025-10-21T08:00:00Z",
  "created_at": "2025-10-21T08:00:00Z",
  "synced_at": "2025-10-21T08:00:05Z"
}
```

**Fetch Mood History**
```typescript
GET /rest/v1/mood_entries?user_id=eq.{user-uuid}&order=timestamp.desc&limit=30
Authorization: Bearer {access_token}

Response 200:
[
  {
    "id": "mood-uuid-1",
    "mood_level": 4,
    "timestamp": "2025-10-21T08:00:00Z",
    ...
  },
  ...
]
```

**Mood Trends Analytics**
```typescript
GET /rest/v1/rpc/mood_trends
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "user_id_param": "user-uuid",
  "start_date": "2025-10-01",
  "end_date": "2025-10-21"
}

Response 200:
{
  "average_mood": 3.8,
  "trend": "improving",
  "best_day": "2025-10-15",
  "activity_correlations": {
    "exercise": 0.72,
    "meditation": 0.65,
    "social": 0.58
  }
}
```

#### Therapeutic Journal

**Create Journal Entry** (encrypted content)
```typescript
POST /rest/v1/journal_entries
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "user_id": "user-uuid",
  "title_encrypted": "base64-encrypted-title",
  "content_encrypted": "base64-encrypted-content",
  "mood_id": "mood-uuid",
  "tags": ["gratitude", "therapy"],
  "timestamp": "2025-10-21T20:00:00Z"
}

Response 201:
{
  "id": "journal-uuid",
  "user_id": "user-uuid",
  "title_encrypted": "...",
  "content_encrypted": "...",
  "created_at": "2025-10-21T20:00:00Z"
}
```

**Fetch Journal Entries** (encrypted)
```typescript
GET /rest/v1/journal_entries?user_id=eq.{user-uuid}&order=timestamp.desc
Authorization: Bearer {access_token}

Response 200:
[
  {
    "id": "journal-uuid",
    "title_encrypted": "...",
    "content_encrypted": "...",
    "timestamp": "2025-10-21T20:00:00Z"
  }
]
```

#### Family Exercises

**Fetch Exercise Library**
```typescript
GET /rest/v1/family_exercises?select=*,category(*)
Authorization: Bearer {access_token}

Response 200:
[
  {
    "id": "exercise-uuid",
    "title": "Family Gratitude Circle",
    "description": "Share one thing you're grateful for today",
    "duration_minutes": 15,
    "category": {
      "id": "cat-uuid",
      "name": "gratitude"
    },
    "instructions": "..."
  }
]
```

**Mark Exercise Complete**
```typescript
POST /rest/v1/exercise_completions
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "user_id": "user-uuid",
  "exercise_id": "exercise-uuid",
  "completed_at": "2025-10-21T18:00:00Z",
  "notes": "Great conversation with kids"
}

Response 201:
{
  "id": "completion-uuid",
  "user_id": "user-uuid",
  "exercise_id": "exercise-uuid",
  "completed_at": "2025-10-21T18:00:00Z"
}
```

#### Crisis Plan & Emergency Resources

**Update Crisis Plan** (encrypted)
```typescript
PUT /rest/v1/crisis_plans?user_id=eq.{user-uuid}
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "warning_signs_encrypted": "base64-encrypted-signs",
  "coping_strategies_encrypted": "base64-encrypted-strategies",
  "emergency_contacts_encrypted": "base64-encrypted-contacts",
  "updated_at": "2025-10-21T14:00:00Z"
}

Response 200:
{
  "id": "crisis-plan-uuid",
  "user_id": "user-uuid",
  "warning_signs_encrypted": "...",
  "updated_at": "2025-10-21T14:00:00Z"
}
```

**Fetch Emergency Resources** (location-based)
```typescript
GET /rest/v1/rpc/emergency_resources
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "radius_miles": 25
}

Response 200:
[
  {
    "id": "resource-uuid",
    "name": "Crisis Text Line",
    "phone": "741741",
    "type": "hotline",
    "available_24_7": true
  },
  {
    "id": "resource-uuid-2",
    "name": "Mental Health Center",
    "address": "123 Main St, San Francisco, CA",
    "phone": "(415) 555-0100",
    "type": "clinic",
    "distance_miles": 2.3
  }
]
```

#### Analytics & Insights

**Fetch User Insights**
```typescript
GET /rest/v1/rpc/user_insights
Authorization: Bearer {access_token}
Content-Type: application/json

{
  "user_id_param": "user-uuid",
  "period": "week"
}

Response 200:
{
  "mood_summary": {
    "average": 3.8,
    "trend": "stable",
    "entries_count": 21
  },
  "journal_summary": {
    "entries_count": 5,
    "avg_words": 250
  },
  "exercise_summary": {
    "completed_count": 3,
    "streak_days": 7
  },
  "recommendations": [
    "Consider scheduling more exercise on low-mood days",
    "Journaling frequency correlates with improved mood"
  ]
}
```

---

## Data Synchronization Strategy

### Sync Architecture (ADR-005)

**Strategy**: Background queue with optimistic UI updates and conflict resolution

**Key Principles**:
1. **Local-First**: All mutations write to local storage immediately
2. **Optimistic UI**: UI updates instantly, sync happens in background
3. **Queue Management**: Failed syncs retry with exponential backoff
4. **Conflict Resolution**: Last-write-wins with client-side conflict detection
5. **Eventual Consistency**: All devices eventually converge to same state

### Sync Flow Diagram

```
User Action (Create Mood Entry)
        ↓
1. Write to AsyncStorage (immediate)
        ↓
2. Update UI optimistically
        ↓
3. Add to sync queue
        ↓
4. Background sync process picks up
        ↓
5. Network check (online/offline)
        ↓
6. If online: POST /rest/v1/mood_entries
        ↓
7. If success: Mark synced, update local record
        ↓
8. If failure: Retry with exponential backoff (5s, 10s, 20s, 40s, 80s)
        ↓
9. If conflict (409): Resolve with conflict strategy
        ↓
10. Update UI with server confirmation
```

### Sync Queue Implementation

```typescript
// src/core/services/SyncService.ts
import { NetworkService } from '@litmoncloud/react-native';
import { StorageService } from './StorageService';
import { MoodEntry, JournalEntry, PromptResponse } from '../models';

export interface SyncQueueItem {
  id: string;
  type: 'mood_entry' | 'journal_entry' | 'prompt_response' | 'exercise_completion';
  operation: 'create' | 'update' | 'delete';
  data: any;
  attempts: number;
  lastAttempt: Date | null;
  createdAt: Date;
}

export class SyncService {
  private static instance: SyncService;
  private readonly SYNC_QUEUE_KEY = 'sync_queue';
  private readonly MAX_RETRIES = 5;
  private syncInterval: NodeJS.Timeout | null = null;

  private constructor(
    private networkService: NetworkService,
    private storageService: StorageService
  ) {}

  public static get shared(): SyncService {
    if (!SyncService.instance) {
      SyncService.instance = new SyncService(
        NetworkService.shared,
        StorageService.shared
      );
    }
    return SyncService.instance;
  }

  /**
   * Start background sync process
   * Runs every 30 seconds when app is active
   */
  startBackgroundSync(): void {
    if (this.syncInterval) return;

    this.syncInterval = setInterval(async () => {
      await this.processSyncQueue();
    }, 30000); // 30 seconds

    // Initial sync on start
    this.processSyncQueue();
  }

  /**
   * Stop background sync
   */
  stopBackgroundSync(): void {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
  }

  /**
   * Add item to sync queue
   */
  async addToQueue(item: Omit<SyncQueueItem, 'id' | 'attempts' | 'lastAttempt' | 'createdAt'>): Promise<void> {
    const queue = await this.getSyncQueue();

    const queueItem: SyncQueueItem = {
      id: `sync_${Date.now()}_${Math.random()}`,
      attempts: 0,
      lastAttempt: null,
      createdAt: new Date(),
      ...item
    };

    queue.push(queueItem);
    await this.saveSyncQueue(queue);
  }

  /**
   * Process sync queue
   */
  private async processSyncQueue(): Promise<void> {
    const queue = await this.getSyncQueue();

    if (queue.length === 0) return;

    // Check network connectivity
    const isOnline = await this.networkService.isConnected();
    if (!isOnline) return;

    const itemsToSync = queue.filter(item =>
      item.attempts < this.MAX_RETRIES &&
      this.shouldRetry(item)
    );

    for (const item of itemsToSync) {
      try {
        await this.syncItem(item);

        // Remove from queue on success
        const updatedQueue = queue.filter(q => q.id !== item.id);
        await this.saveSyncQueue(updatedQueue);

      } catch (error) {
        // Update retry count and timestamp
        item.attempts += 1;
        item.lastAttempt = new Date();
        await this.saveSyncQueue(queue);

        console.error(`Sync failed for item ${item.id}:`, error);
      }
    }
  }

  /**
   * Sync individual item
   */
  private async syncItem(item: SyncQueueItem): Promise<void> {
    switch (item.type) {
      case 'mood_entry':
        return this.syncMoodEntry(item);
      case 'journal_entry':
        return this.syncJournalEntry(item);
      case 'prompt_response':
        return this.syncPromptResponse(item);
      case 'exercise_completion':
        return this.syncExerciseCompletion(item);
      default:
        throw new Error(`Unknown sync type: ${item.type}`);
    }
  }

  /**
   * Sync mood entry
   */
  private async syncMoodEntry(item: SyncQueueItem): Promise<void> {
    const endpoint = '/rest/v1/mood_entries';

    switch (item.operation) {
      case 'create':
        await this.networkService.post(endpoint, item.data);
        break;
      case 'update':
        await this.networkService.patch(`${endpoint}?id=eq.${item.data.id}`, item.data);
        break;
      case 'delete':
        await this.networkService.delete(`${endpoint}?id=eq.${item.data.id}`);
        break;
    }
  }

  /**
   * Sync journal entry (encrypted)
   */
  private async syncJournalEntry(item: SyncQueueItem): Promise<void> {
    const endpoint = '/rest/v1/journal_entries';

    switch (item.operation) {
      case 'create':
        await this.networkService.post(endpoint, item.data);
        break;
      case 'update':
        await this.networkService.patch(`${endpoint}?id=eq.${item.data.id}`, item.data);
        break;
      case 'delete':
        await this.networkService.delete(`${endpoint}?id=eq.${item.data.id}`);
        break;
    }
  }

  /**
   * Sync prompt response
   */
  private async syncPromptResponse(item: SyncQueueItem): Promise<void> {
    await this.networkService.post('/rest/v1/prompt_responses', item.data);
  }

  /**
   * Sync exercise completion
   */
  private async syncExerciseCompletion(item: SyncQueueItem): Promise<void> {
    await this.networkService.post('/rest/v1/exercise_completions', item.data);
  }

  /**
   * Exponential backoff retry logic
   */
  private shouldRetry(item: SyncQueueItem): boolean {
    if (!item.lastAttempt) return true;

    const backoffMs = this.calculateBackoff(item.attempts);
    const timeSinceLastAttempt = Date.now() - item.lastAttempt.getTime();

    return timeSinceLastAttempt >= backoffMs;
  }

  /**
   * Calculate exponential backoff delay
   * 5s, 10s, 20s, 40s, 80s
   */
  private calculateBackoff(attempts: number): number {
    const baseDelay = 5000; // 5 seconds
    return baseDelay * Math.pow(2, attempts);
  }

  /**
   * Get sync queue from storage
   */
  private async getSyncQueue(): Promise<SyncQueueItem[]> {
    const queue = await this.storageService.get<SyncQueueItem[]>(this.SYNC_QUEUE_KEY);
    return queue || [];
  }

  /**
   * Save sync queue to storage
   */
  private async saveSyncQueue(queue: SyncQueueItem[]): Promise<void> {
    await this.storageService.set(this.SYNC_QUEUE_KEY, queue);
  }

  /**
   * Manual sync trigger (pull to refresh)
   */
  async manualSync(): Promise<void> {
    await this.processSyncQueue();
  }

  /**
   * Get sync queue status
   */
  async getSyncStatus(): Promise<{ pending: number; failed: number }> {
    const queue = await this.getSyncQueue();

    return {
      pending: queue.filter(item => item.attempts < this.MAX_RETRIES).length,
      failed: queue.filter(item => item.attempts >= this.MAX_RETRIES).length
    };
  }
}
```

### Conflict Resolution Strategy

**Last-Write-Wins** with timestamp comparison:

```typescript
// src/core/services/ConflictResolver.ts
export class ConflictResolver {
  /**
   * Resolve conflict between local and server data
   */
  resolveConflict<T extends { updated_at: Date }>(
    local: T,
    server: T
  ): T {
    // Compare timestamps
    const localTime = new Date(local.updated_at).getTime();
    const serverTime = new Date(server.updated_at).getTime();

    // Keep most recent version
    if (localTime > serverTime) {
      console.log('Local version newer, keeping local');
      return local;
    } else {
      console.log('Server version newer, keeping server');
      return server;
    }
  }

  /**
   * Merge conflicting journal entries (manual resolution)
   */
  async mergeJournalEntries(
    local: JournalEntry,
    server: JournalEntry
  ): Promise<JournalEntry> {
    // For journal entries, preserve both versions
    // and let user manually resolve
    return {
      ...server,
      conflictData: local,
      hasConflict: true
    };
  }
}
```

---

## Authentication & Authorization

### Sign in with Apple Flow

```typescript
// src/core/services/AppleAuthService.ts
import { appleAuth } from '@invertase/react-native-apple-authentication';
import { supabase } from './SupabaseClient';

export class AppleAuthService {
  async signInWithApple(): Promise<{
    user: User;
    session: Session;
  }> {
    // Request Apple ID credential
    const appleAuthRequestResponse = await appleAuth.performRequest({
      requestedOperation: appleAuth.Operation.LOGIN,
      requestedScopes: [
        appleAuth.Scope.EMAIL,
        appleAuth.Scope.FULL_NAME
      ]
    });

    // Extract ID token
    const { identityToken } = appleAuthRequestResponse;

    if (!identityToken) {
      throw new Error('Apple Sign-In failed - no identity token');
    }

    // Authenticate with Supabase
    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'apple',
      token: identityToken
    });

    if (error) {
      throw new Error(`Supabase auth failed: ${error.message}`);
    }

    return {
      user: data.user,
      session: data.session
    };
  }

  async signOut(): Promise<void> {
    await supabase.auth.signOut();
  }
}
```

### Row Level Security (RLS) Policies

Supabase RLS ensures users can only access their own data:

```sql
-- Enable RLS on mood_entries table
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;

-- Users can only select their own mood entries
CREATE POLICY "Users can view their own mood entries"
  ON mood_entries FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only insert their own mood entries
CREATE POLICY "Users can create their own mood entries"
  ON mood_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only update their own mood entries
CREATE POLICY "Users can update their own mood entries"
  ON mood_entries FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own mood entries
CREATE POLICY "Users can delete their own mood entries"
  ON mood_entries FOR DELETE
  USING (auth.uid() = user_id);

-- Similar RLS policies for:
-- - journal_entries
-- - prompt_responses
-- - crisis_plans
-- - exercise_completions
```

---

## Data Models & Schemas

### TypeScript Interfaces with Zod Validation

```typescript
// src/core/models/MoodEntry.ts
import { z } from 'zod';

export const MoodEntrySchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  mood_level: z.number().int().min(1).max(5),
  notes: z.string().max(500).optional(),
  activities: z.array(z.string()),
  timestamp: z.date(),
  created_at: z.date(),
  updated_at: z.date(),
  synced_at: z.date().nullable(),
  is_synced: z.boolean().default(false)
});

export type MoodEntry = z.infer<typeof MoodEntrySchema>;

export const CreateMoodEntrySchema = MoodEntrySchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true
});

export type CreateMoodEntryInput = z.infer<typeof CreateMoodEntrySchema>;

// Factory function with validation
export const createMoodEntry = (data: any): MoodEntry => {
  return MoodEntrySchema.parse(data);
};
```

```typescript
// src/core/models/JournalEntry.ts
import { z } from 'zod';

export const JournalEntrySchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  title_encrypted: z.string(), // Base64 encrypted
  content_encrypted: z.string(), // Base64 encrypted
  mood_id: z.string().uuid().nullable(),
  tags: z.array(z.string()),
  timestamp: z.date(),
  created_at: z.date(),
  updated_at: z.date(),
  synced_at: z.date().nullable(),
  is_synced: z.boolean().default(false)
});

export type JournalEntry = z.infer<typeof JournalEntrySchema>;

export const CreateJournalEntrySchema = JournalEntrySchema.omit({
  id: true,
  created_at: true,
  updated_at: true,
  synced_at: true,
  is_synced: true
});

export type CreateJournalEntryInput = z.infer<typeof CreateJournalEntrySchema>;
```

```typescript
// src/core/models/PromptResponse.ts
import { z } from 'zod';

export const PromptResponseSchema = z.object({
  id: z.string().uuid(),
  prompt_id: z.string().uuid(),
  user_id: z.string().uuid(),
  response_text: z.string().max(2000),
  completed_at: z.date(),
  created_at: z.date(),
  synced_at: z.date().nullable(),
  is_synced: z.boolean().default(false)
});

export type PromptResponse = z.infer<typeof PromptResponseSchema>;
```

### PostgreSQL Database Schema

```sql
-- Users table (managed by Supabase Auth)
-- auth.users table automatically created

-- Conversation prompts
CREATE TABLE conversation_prompts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL CHECK (category IN ('family', 'relationship', 'self-reflection')),
  question TEXT NOT NULL,
  follow_up_questions TEXT[],
  date DATE NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Prompt responses
CREATE TABLE prompt_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  prompt_id UUID NOT NULL REFERENCES conversation_prompts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  response_text TEXT NOT NULL,
  completed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(prompt_id, user_id)
);

-- Mood entries
CREATE TABLE mood_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mood_level INTEGER NOT NULL CHECK (mood_level BETWEEN 1 AND 5),
  notes TEXT,
  activities TEXT[],
  timestamp TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Journal entries (encrypted content)
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title_encrypted TEXT NOT NULL,
  content_encrypted TEXT NOT NULL,
  mood_id UUID REFERENCES mood_entries(id) ON DELETE SET NULL,
  tags TEXT[],
  timestamp TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Family exercises
CREATE TABLE family_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  instructions TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  category_id UUID NOT NULL REFERENCES exercise_categories(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Exercise categories
CREATE TABLE exercise_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Exercise completions
CREATE TABLE exercise_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise_id UUID NOT NULL REFERENCES family_exercises(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Crisis plans (encrypted)
CREATE TABLE crisis_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  warning_signs_encrypted TEXT NOT NULL,
  coping_strategies_encrypted TEXT NOT NULL,
  emergency_contacts_encrypted TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Emergency resources
CREATE TABLE emergency_resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('hotline', 'clinic', 'hospital', 'support_group')),
  phone TEXT,
  address TEXT,
  latitude DECIMAL(9,6),
  longitude DECIMAL(9,6),
  available_24_7 BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_mood_entries_user_timestamp ON mood_entries(user_id, timestamp DESC);
CREATE INDEX idx_journal_entries_user_timestamp ON journal_entries(user_id, timestamp DESC);
CREATE INDEX idx_prompt_responses_user ON prompt_responses(user_id);
CREATE INDEX idx_exercise_completions_user ON exercise_completions(user_id);
CREATE INDEX idx_emergency_resources_location ON emergency_resources USING GIST(ll_to_earth(latitude, longitude));

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_mood_entries_updated_at
  BEFORE UPDATE ON mood_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_journal_entries_updated_at
  BEFORE UPDATE ON journal_entries
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_crisis_plans_updated_at
  BEFORE UPDATE ON crisis_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

---

## Repository Pattern

### Abstract Repository Interface

```typescript
// src/core/repositories/BaseRepository.ts
export interface BaseRepository<T, CreateInput, UpdateInput> {
  getAll(): Promise<T[]>;
  getById(id: string): Promise<T | null>;
  create(input: CreateInput): Promise<T>;
  update(id: string, input: UpdateInput): Promise<T>;
  delete(id: string): Promise<void>;
}
```

### Mood Entry Repository

```typescript
// src/features/wellness/repositories/MoodEntryRepository.ts
import { BaseRepository } from '@/core/repositories/BaseRepository';
import { MoodEntry, CreateMoodEntryInput } from '@/core/models/MoodEntry';
import { StorageService } from '@/core/services/StorageService';
import { SyncService } from '@/core/services/SyncService';
import { supabase } from '@/core/services/SupabaseClient';
import { v4 as uuidv4 } from 'uuid';

export class MoodEntryRepository implements BaseRepository<MoodEntry, CreateMoodEntryInput, Partial<MoodEntry>> {
  private readonly STORAGE_KEY = 'mood_entries';

  constructor(
    private storageService: StorageService,
    private syncService: SyncService
  ) {}

  /**
   * Get all mood entries (local-first)
   */
  async getAll(): Promise<MoodEntry[]> {
    // Try local storage first
    const localEntries = await this.storageService.get<MoodEntry[]>(this.STORAGE_KEY);

    if (localEntries && localEntries.length > 0) {
      return localEntries.sort((a, b) =>
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    }

    // If empty, try fetching from server
    try {
      const { data, error } = await supabase
        .from('mood_entries')
        .select('*')
        .order('timestamp', { ascending: false });

      if (error) throw error;

      // Cache locally
      await this.storageService.set(this.STORAGE_KEY, data);

      return data as MoodEntry[];
    } catch (error) {
      console.error('Failed to fetch mood entries from server:', error);
      return [];
    }
  }

  /**
   * Get mood entry by ID
   */
  async getById(id: string): Promise<MoodEntry | null> {
    const entries = await this.getAll();
    return entries.find(entry => entry.id === id) || null;
  }

  /**
   * Create mood entry (optimistic local-first)
   */
  async create(input: CreateMoodEntryInput): Promise<MoodEntry> {
    const newEntry: MoodEntry = {
      id: uuidv4(),
      created_at: new Date(),
      updated_at: new Date(),
      synced_at: null,
      is_synced: false,
      ...input
    };

    // 1. Save locally immediately
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

  /**
   * Update mood entry
   */
  async update(id: string, input: Partial<MoodEntry>): Promise<MoodEntry> {
    const entries = await this.getAll();
    const index = entries.findIndex(entry => entry.id === id);

    if (index === -1) {
      throw new Error(`Mood entry not found: ${id}`);
    }

    const updatedEntry: MoodEntry = {
      ...entries[index],
      ...input,
      updated_at: new Date(),
      is_synced: false
    };

    entries[index] = updatedEntry;
    await this.storageService.set(this.STORAGE_KEY, entries);

    // Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'update',
      data: updatedEntry
    });

    return updatedEntry;
  }

  /**
   * Delete mood entry
   */
  async delete(id: string): Promise<void> {
    const entries = await this.getAll();
    const filteredEntries = entries.filter(entry => entry.id !== id);

    await this.storageService.set(this.STORAGE_KEY, filteredEntries);

    // Add to sync queue
    await this.syncService.addToQueue({
      type: 'mood_entry',
      operation: 'delete',
      data: { id }
    });
  }

  /**
   * Get mood trends (server-side analytics)
   */
  async getMoodTrends(startDate: Date, endDate: Date): Promise<{
    average_mood: number;
    trend: 'improving' | 'stable' | 'declining';
    activity_correlations: Record<string, number>;
  }> {
    const { data, error } = await supabase.rpc('mood_trends', {
      user_id_param: (await supabase.auth.getUser()).data.user?.id,
      start_date: startDate.toISOString().split('T')[0],
      end_date: endDate.toISOString().split('T')[0]
    });

    if (error) throw error;

    return data;
  }
}
```

### Journal Entry Repository (with Encryption)

```typescript
// src/features/journal/repositories/JournalEntryRepository.ts
import { BaseRepository } from '@/core/repositories/BaseRepository';
import { JournalEntry, CreateJournalEntryInput } from '@/core/models/JournalEntry';
import { SecureStorageService } from '@litmoncloud/react-native';
import { SyncService } from '@/core/services/SyncService';
import { supabase } from '@/core/services/SupabaseClient';
import { v4 as uuidv4 } from 'uuid';
import * as Crypto from 'expo-crypto';

export class JournalEntryRepository implements BaseRepository<JournalEntry, CreateJournalEntryInput, Partial<JournalEntry>> {
  private readonly STORAGE_PREFIX = 'journal_';
  private readonly ENCRYPTION_KEY = 'journal-aes-256-key';

  constructor(
    private secureStorage: SecureStorageService,
    private syncService: SyncService
  ) {}

  /**
   * Encrypt content with AES-256
   */
  private async encrypt(plaintext: string): Promise<string> {
    return await this.secureStorage.encrypt(plaintext, this.ENCRYPTION_KEY);
  }

  /**
   * Decrypt content
   */
  private async decrypt(ciphertext: string): Promise<string> {
    return await this.secureStorage.decrypt(ciphertext, this.ENCRYPTION_KEY);
  }

  /**
   * Get all journal entries (encrypted)
   */
  async getAll(): Promise<JournalEntry[]> {
    try {
      const keys = await this.secureStorage.getAllKeys();
      const journalKeys = keys.filter(key => key.startsWith(this.STORAGE_PREFIX));

      const entries: JournalEntry[] = [];

      for (const key of journalKeys) {
        const encryptedData = await this.secureStorage.getSecureItem(key);
        if (encryptedData) {
          const decrypted = await this.decrypt(encryptedData);
          entries.push(JSON.parse(decrypted));
        }
      }

      return entries.sort((a, b) =>
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );
    } catch (error) {
      console.error('Failed to get journal entries:', error);
      return [];
    }
  }

  /**
   * Get journal entry by ID
   */
  async getById(id: string): Promise<JournalEntry | null> {
    try {
      const encryptedData = await this.secureStorage.getSecureItem(`${this.STORAGE_PREFIX}${id}`);

      if (!encryptedData) return null;

      const decrypted = await this.decrypt(encryptedData);
      return JSON.parse(decrypted);
    } catch (error) {
      console.error(`Failed to get journal entry ${id}:`, error);
      return null;
    }
  }

  /**
   * Create journal entry (encrypted)
   */
  async create(input: CreateJournalEntryInput): Promise<JournalEntry> {
    const newEntry: JournalEntry = {
      id: uuidv4(),
      created_at: new Date(),
      updated_at: new Date(),
      synced_at: null,
      is_synced: false,
      ...input
    };

    // Encrypt and save locally
    const encrypted = await this.encrypt(JSON.stringify(newEntry));
    await this.secureStorage.setSecureItem(`${this.STORAGE_PREFIX}${newEntry.id}`, encrypted);

    // Prepare server payload (double encrypted)
    const serverPayload = {
      ...newEntry,
      title_encrypted: await this.encrypt(newEntry.title_encrypted),
      content_encrypted: await this.encrypt(newEntry.content_encrypted)
    };

    // Add to sync queue
    await this.syncService.addToQueue({
      type: 'journal_entry',
      operation: 'create',
      data: serverPayload
    });

    return newEntry;
  }

  /**
   * Update journal entry
   */
  async update(id: string, input: Partial<JournalEntry>): Promise<JournalEntry> {
    const existing = await this.getById(id);

    if (!existing) {
      throw new Error(`Journal entry not found: ${id}`);
    }

    const updatedEntry: JournalEntry = {
      ...existing,
      ...input,
      updated_at: new Date(),
      is_synced: false
    };

    // Encrypt and save locally
    const encrypted = await this.encrypt(JSON.stringify(updatedEntry));
    await this.secureStorage.setSecureItem(`${this.STORAGE_PREFIX}${id}`, encrypted);

    // Add to sync queue
    await this.syncService.addToQueue({
      type: 'journal_entry',
      operation: 'update',
      data: updatedEntry
    });

    return updatedEntry;
  }

  /**
   * Delete journal entry
   */
  async delete(id: string): Promise<void> {
    await this.secureStorage.removeSecureItem(`${this.STORAGE_PREFIX}${id}`);

    // Add to sync queue
    await this.syncService.addToQueue({
      type: 'journal_entry',
      operation: 'delete',
      data: { id }
    });
  }
}
```

---

## Network Configuration

### Supabase Client Setup

```typescript
// src/core/services/SupabaseClient.ts
import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '@env';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false
  },
  global: {
    headers: {
      'X-Client-Info': 'rediscover-talk-mobile/1.0.0'
    }
  }
});
```

### Network Service Integration

```typescript
// src/core/services/NetworkService.ts (Extension)
import { NetworkService as LitmonNetworkService } from '@litmoncloud/react-native';

class SupabaseNetworkService extends LitmonNetworkService {
  constructor() {
    super();

    // Override base URL with Supabase REST API
    this.axiosInstance.defaults.baseURL = process.env.SUPABASE_URL;

    // Add Supabase-specific headers
    this.axiosInstance.interceptors.request.use(config => {
      config.headers['apikey'] = process.env.SUPABASE_ANON_KEY;
      config.headers['Authorization'] = `Bearer ${supabase.auth.session()?.access_token}`;
      return config;
    });
  }
}

export const networkService = new SupabaseNetworkService();
```

---

## Offline Functionality

### Offline Detection

```typescript
// src/core/services/NetworkMonitor.ts
import NetInfo from '@react-native-community/netinfo';
import { EventEmitter } from 'events';

export class NetworkMonitor extends EventEmitter {
  private static instance: NetworkMonitor;
  private isOnline: boolean = true;

  private constructor() {
    super();
    this.startMonitoring();
  }

  public static get shared(): NetworkMonitor {
    if (!NetworkMonitor.instance) {
      NetworkMonitor.instance = new NetworkMonitor();
    }
    return NetworkMonitor.instance;
  }

  private startMonitoring(): void {
    NetInfo.addEventListener(state => {
      const wasOnline = this.isOnline;
      this.isOnline = state.isConnected ?? false;

      if (wasOnline !== this.isOnline) {
        this.emit('connectionChange', this.isOnline);

        if (this.isOnline) {
          this.emit('online');
        } else {
          this.emit('offline');
        }
      }
    });
  }

  public async checkConnection(): Promise<boolean> {
    const state = await NetInfo.fetch();
    return state.isConnected ?? false;
  }

  public getConnectionStatus(): boolean {
    return this.isOnline;
  }
}
```

### Offline UI Indicator

```typescript
// src/components/OfflineBanner.tsx
import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { NetworkMonitor } from '@/core/services/NetworkMonitor';

export const OfflineBanner: React.FC = () => {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    const networkMonitor = NetworkMonitor.shared;

    const handleConnectionChange = (online: boolean) => {
      setIsOnline(online);
    };

    networkMonitor.on('connectionChange', handleConnectionChange);

    // Check initial status
    setIsOnline(networkMonitor.getConnectionStatus());

    return () => {
      networkMonitor.off('connectionChange', handleConnectionChange);
    };
  }, []);

  if (isOnline) return null;

  return (
    <View style={styles.banner}>
      <Text style={styles.text}>Offline - Changes will sync when online</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  banner: {
    backgroundColor: '#FFC107',
    padding: 8,
    alignItems: 'center'
  },
  text: {
    color: '#000',
    fontSize: 14,
    fontWeight: '600'
  }
});
```

---

## Real-time Features

### Real-time Subscriptions (Optional for Family Exercises)

```typescript
// src/features/family/services/FamilyRealtimeService.ts
import { supabase } from '@/core/services/SupabaseClient';
import { RealtimeChannel } from '@supabase/supabase-js';

export class FamilyRealtimeService {
  private channel: RealtimeChannel | null = null;

  /**
   * Subscribe to family exercise completions
   */
  subscribeToExerciseCompletions(
    onCompletion: (completion: ExerciseCompletion) => void
  ): void {
    this.channel = supabase
      .channel('exercise_completions')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'exercise_completions',
          filter: `user_id=eq.${supabase.auth.user()?.id}`
        },
        payload => {
          onCompletion(payload.new as ExerciseCompletion);
        }
      )
      .subscribe();
  }

  /**
   * Unsubscribe from real-time updates
   */
  unsubscribe(): void {
    if (this.channel) {
      supabase.removeChannel(this.channel);
      this.channel = null;
    }
  }
}
```

---

## Security & Privacy

### End-to-End Encryption for Sensitive Data

**Encryption Keys**:
- User-specific encryption key derived from device hardware + user PIN
- Stored in iOS Keychain / Android Keystore (hardware-backed)
- Never transmitted to server

**Double Encryption Pattern**:
1. **Client-Side Encryption**: Encrypt with user key before local storage
2. **Server-Side Encryption**: Encrypted data is further encrypted in transit (TLS)
3. **Server Storage**: Server stores encrypted blobs without decryption capability

### Data Privacy Checklist

- ✅ End-to-end encryption for journal entries and crisis plans
- ✅ AES-256 encryption at rest
- ✅ TLS 1.3 encryption in transit
- ✅ Row Level Security (RLS) for authorization
- ✅ Biometric authentication for sensitive features
- ✅ Audit logging for security events
- ✅ User data deletion (GDPR right to be forgotten)
- ✅ Data export functionality
- ✅ Privacy policy and consent workflows
- ✅ No third-party analytics for sensitive features

---

## Testing Strategy

### Mock API Server

```typescript
// src/core/testing/MockSupabaseServer.ts
import { setupServer } from 'msw/node';
import { rest } from 'msw';

export const mockSupabaseServer = setupServer(
  // Mock mood entries endpoint
  rest.get('/rest/v1/mood_entries', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json([
        {
          id: 'mood-uuid-1',
          user_id: 'user-uuid',
          mood_level: 4,
          timestamp: '2025-10-21T08:00:00Z'
        }
      ])
    );
  }),

  // Mock create mood entry
  rest.post('/rest/v1/mood_entries', async (req, res, ctx) => {
    const body = await req.json();
    return res(
      ctx.status(201),
      ctx.json({
        id: 'new-mood-uuid',
        ...body,
        created_at: new Date().toISOString()
      })
    );
  }),

  // Mock journal entries endpoint
  rest.get('/rest/v1/journal_entries', (req, res, ctx) => {
    return res(
      ctx.status(200),
      ctx.json([
        {
          id: 'journal-uuid-1',
          user_id: 'user-uuid',
          title_encrypted: 'encrypted-title',
          content_encrypted: 'encrypted-content',
          timestamp: '2025-10-21T20:00:00Z'
        }
      ])
    );
  })
);

// Setup/teardown for tests
beforeAll(() => mockSupabaseServer.listen());
afterEach(() => mockSupabaseServer.resetHandlers());
afterAll(() => mockSupabaseServer.close());
```

### Repository Integration Tests

```typescript
// src/features/wellness/repositories/__tests__/MoodEntryRepository.test.ts
import { MoodEntryRepository } from '../MoodEntryRepository';
import { StorageService } from '@/core/services/StorageService';
import { SyncService } from '@/core/services/SyncService';
import { mockSupabaseServer } from '@/core/testing/MockSupabaseServer';

describe('MoodEntryRepository', () => {
  let repository: MoodEntryRepository;
  let storageService: StorageService;
  let syncService: SyncService;

  beforeEach(() => {
    storageService = StorageService.shared;
    syncService = SyncService.shared;
    repository = new MoodEntryRepository(storageService, syncService);
  });

  afterEach(async () => {
    await storageService.clear();
  });

  describe('create', () => {
    it('should create mood entry locally and add to sync queue', async () => {
      const input = {
        user_id: 'user-uuid',
        mood_level: 4,
        notes: 'Feeling great',
        activities: ['exercise'],
        timestamp: new Date()
      };

      const entry = await repository.create(input);

      // Verify local storage
      expect(entry.id).toBeDefined();
      expect(entry.mood_level).toBe(4);
      expect(entry.is_synced).toBe(false);

      // Verify sync queue
      const syncStatus = await syncService.getSyncStatus();
      expect(syncStatus.pending).toBe(1);
    });

    it('should handle offline creation gracefully', async () => {
      // Simulate offline
      jest.spyOn(networkService, 'isConnected').mockResolvedValue(false);

      const entry = await repository.create({
        user_id: 'user-uuid',
        mood_level: 3,
        activities: [],
        timestamp: new Date()
      });

      expect(entry.id).toBeDefined();
      expect(entry.is_synced).toBe(false);
    });
  });

  describe('getAll', () => {
    it('should fetch from local storage first', async () => {
      const mockEntries = [
        { id: '1', mood_level: 4, timestamp: new Date() },
        { id: '2', mood_level: 3, timestamp: new Date() }
      ];

      await storageService.set('mood_entries', mockEntries);

      const entries = await repository.getAll();

      expect(entries).toHaveLength(2);
      expect(entries[0].mood_level).toBe(4);
    });

    it('should fallback to server if local storage empty', async () => {
      const entries = await repository.getAll();

      // Should fetch from mock server
      expect(entries).toHaveLength(1);
      expect(entries[0].id).toBe('mood-uuid-1');
    });
  });
});
```

### Sync Service Tests

```typescript
// src/core/services/__tests__/SyncService.test.ts
import { SyncService } from '../SyncService';
import { NetworkService } from '@litmoncloud/react-native';
import { mockSupabaseServer } from '@/core/testing/MockSupabaseServer';

describe('SyncService', () => {
  let syncService: SyncService;

  beforeEach(() => {
    syncService = SyncService.shared;
  });

  describe('processSyncQueue', () => {
    it('should sync pending items when online', async () => {
      // Add item to queue
      await syncService.addToQueue({
        type: 'mood_entry',
        operation: 'create',
        data: {
          id: 'test-mood-uuid',
          mood_level: 4,
          timestamp: new Date()
        }
      });

      // Simulate online
      jest.spyOn(NetworkService.shared, 'isConnected').mockResolvedValue(true);

      // Process queue
      await syncService.processSyncQueue();

      // Verify queue is empty
      const status = await syncService.getSyncStatus();
      expect(status.pending).toBe(0);
    });

    it('should skip sync when offline', async () => {
      await syncService.addToQueue({
        type: 'mood_entry',
        operation: 'create',
        data: { id: 'test', mood_level: 3 }
      });

      // Simulate offline
      jest.spyOn(NetworkService.shared, 'isConnected').mockResolvedValue(false);

      await syncService.processSyncQueue();

      // Verify queue still has pending item
      const status = await syncService.getSyncStatus();
      expect(status.pending).toBe(1);
    });

    it('should retry with exponential backoff on failure', async () => {
      // Mock network failure
      mockSupabaseServer.use(
        rest.post('/rest/v1/mood_entries', (req, res, ctx) => {
          return res(ctx.status(500));
        })
      );

      await syncService.addToQueue({
        type: 'mood_entry',
        operation: 'create',
        data: { id: 'test', mood_level: 4 }
      });

      jest.spyOn(NetworkService.shared, 'isConnected').mockResolvedValue(true);

      // First attempt
      await syncService.processSyncQueue();

      let queue = await syncService.getSyncQueue();
      expect(queue[0].attempts).toBe(1);

      // Second attempt (should wait for backoff)
      await syncService.processSyncQueue();

      queue = await syncService.getSyncQueue();
      expect(queue[0].attempts).toBe(1); // Still 1 due to backoff
    });
  });
});
```

---

## Appendix

### API Rate Limiting

Supabase default rate limits:
- **Authenticated requests**: 100 requests/second
- **Anonymous requests**: 10 requests/second

Client-side rate limiting:
```typescript
// src/core/services/RateLimiter.ts
export class RateLimiter {
  private requestTimestamps: number[] = [];
  private readonly maxRequests = 50;
  private readonly timeWindow = 1000; // 1 second

  async checkRateLimit(): Promise<boolean> {
    const now = Date.now();

    // Remove timestamps outside time window
    this.requestTimestamps = this.requestTimestamps.filter(
      timestamp => now - timestamp < this.timeWindow
    );

    if (this.requestTimestamps.length >= this.maxRequests) {
      return false; // Rate limit exceeded
    }

    this.requestTimestamps.push(now);
    return true;
  }
}
```

### Performance Optimization

**Request Batching**:
```typescript
// src/core/services/BatchService.ts
export class BatchService {
  private batchQueue: Array<{ endpoint: string; data: any }> = [];
  private batchTimer: NodeJS.Timeout | null = null;

  addToBatch(endpoint: string, data: any): void {
    this.batchQueue.push({ endpoint, data });

    if (!this.batchTimer) {
      this.batchTimer = setTimeout(() => this.flushBatch(), 1000);
    }
  }

  private async flushBatch(): Promise<void> {
    if (this.batchQueue.length === 0) return;

    const batch = [...this.batchQueue];
    this.batchQueue = [];
    this.batchTimer = null;

    // Send batch request
    await supabase.rpc('batch_operations', { operations: batch });
  }
}
```

---

## Conclusion

This backend integration architecture provides a robust, offline-first foundation for Rediscover Talk with:

- ✅ **Offline-First**: All features work without network connectivity
- ✅ **Secure**: End-to-end encryption for sensitive data, RLS for authorization
- ✅ **Scalable**: Supabase infrastructure handles growth without code changes
- ✅ **Testable**: Mock API server and comprehensive test coverage
- ✅ **Privacy-First**: HIPAA-compliant data handling with user control
- ✅ **Performant**: Background sync, request batching, local caching

**Next Steps**: Review ADR-004 (Backend Platform Selection) and ADR-005 (Sync Strategy) for architectural decision rationale.
