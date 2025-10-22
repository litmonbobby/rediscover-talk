# ADR 004: Backend Platform Selection

**Status**: Accepted
**Date**: 2025-10-21
**Deciders**: Enterprise Architect, Backend Specialist, iOS Backend Integration Specialist
**Framework Compliance**: LitmonCloud Mobile Development Framework v3.1

---

## Context

Rediscover Talk requires a backend platform to handle:

1. **User authentication** (Sign in with Apple, anonymous auth)
2. **Data persistence** (mood logs, journal entries, crisis plans, conversation prompts)
3. **Real-time features** (optional family exercise notifications)
4. **File storage** (optional journal attachments in future)
5. **Analytics** (mood trends, activity correlations)
6. **Authorization** (row-level security for user data)

**Key Requirements**:
- Offline-first mobile architecture (local data persistence priority)
- HIPAA-compliance readiness (encryption at rest and in transit)
- Privacy-first design (end-to-end encryption for sensitive data)
- Scalability (support growth from MVP to thousands of users)
- Developer experience (minimize backend maintenance, maximize mobile development)
- Cost-effective (free tier for MVP, affordable scaling)
- TypeScript/JavaScript ecosystem compatibility

**Mental Health App Constraints**:
- Sensitive data requires encryption before transmission
- User data must be isolated (row-level security)
- No third-party analytics for personal health information
- Data portability and export capabilities
- Right to be forgotten (GDPR/CCPA compliance)

---

## Decision

**Selected Solution**: **Supabase** (PostgreSQL + Realtime + Storage + Auth)

Supabase provides an open-source Firebase alternative with PostgreSQL as the database, built-in authentication, row-level security, real-time subscriptions, and edge functions. It aligns perfectly with LitmonCloud's offline-first architecture and privacy-first requirements.

**Architecture**:
- **Database**: PostgreSQL with JSON support and RLS policies
- **Authentication**: Supabase Auth with Sign in with Apple integration
- **Real-time**: PostgreSQL logical replication with WebSocket subscriptions
- **Storage**: S3-compatible object storage for file uploads
- **Edge Functions**: Deno-based serverless functions for backend logic
- **Client SDK**: TypeScript SDK with automatic type generation

---

## Alternatives Considered

### Option 1: Firebase (Google Cloud Platform)

**Pros**:
- ✅ Mature ecosystem with extensive documentation
- ✅ Real-time database with offline persistence
- ✅ Google Sign-In and Apple Sign-In support
- ✅ Cloud Functions for serverless backend logic
- ✅ Analytics and monitoring built-in
- ✅ Generous free tier (Spark plan)

**Cons**:
- ❌ NoSQL database (Firestore) less suitable for relational mental health data (mood entries → journal entries → analytics)
- ❌ Limited querying capabilities (no SQL, complex filters difficult)
- ❌ Vendor lock-in (proprietary Google platform)
- ❌ Privacy concerns (Google's data analytics ecosystem)
- ❌ Security rules complexity for row-level isolation
- ❌ Limited self-hosting options (vendor dependency)
- ❌ Cost scaling unpredictable (read/write operations charged separately)

**Verdict**: NoSQL limitations and vendor lock-in outweigh benefits. Mental health data requires relational structure (mood trends, journal-mood correlations, analytics queries).

---

### Option 2: AWS Amplify (Amazon Web Services)

**Pros**:
- ✅ Full AWS ecosystem integration
- ✅ AppSync GraphQL API with offline sync
- ✅ Cognito authentication with social providers
- ✅ DynamoDB for NoSQL or RDS for PostgreSQL
- ✅ S3 storage for files
- ✅ Lambda functions for backend logic

**Cons**:
- ❌ Complex setup and configuration (steep learning curve)
- ❌ Expensive for small teams (AWS pricing complexity)
- ❌ Amplify CLI heavyweight (slow build times)
- ❌ GraphQL overhead for simple CRUD operations
- ❌ Vendor lock-in (AWS-specific services)
- ❌ No built-in row-level security (must implement manually)
- ❌ Documentation fragmented across AWS services

**Verdict**: Complexity and cost outweigh benefits for MVP. Better suited for enterprise-scale applications with dedicated DevOps teams.

---

### Option 3: Custom Node.js Backend (Express + PostgreSQL)

**Pros**:
- ✅ Full control over backend logic and architecture
- ✅ No vendor lock-in (self-hostable anywhere)
- ✅ Flexible technology choices (PostgreSQL, Redis, etc.)
- ✅ Custom optimization for mental health workflows
- ✅ No platform limitations or quotas

**Cons**:
- ❌ High development overhead (auth, API, real-time, storage all custom-built)
- ❌ Security implementation burden (JWT, RLS, encryption all manual)
- ❌ Infrastructure management (DevOps, scaling, monitoring, backups)
- ❌ Time to market delay (3-6 months backend development before mobile app)
- ❌ Maintenance burden (security patches, dependency updates, infrastructure)
- ❌ Team resource allocation (backend developers needed)
- ❌ No free tier (hosting costs from day 1)

**Verdict**: Development overhead too high for MVP. Better suited for post-MVP when specific backend optimizations are required.

---

### Option 4: Supabase (PostgreSQL + Realtime + Auth) - Selected

**Pros**:
- ✅ **PostgreSQL**: Robust relational database with JSON support, perfect for mental health data relationships
- ✅ **Row Level Security (RLS)**: Built-in database-level authorization, users can only access their own data
- ✅ **TypeScript SDK**: Automatic type generation from database schema, excellent developer experience
- ✅ **Realtime**: PostgreSQL logical replication with WebSocket subscriptions (optional for family features)
- ✅ **Auth**: Built-in authentication with Sign in with Apple, email/password, anonymous users
- ✅ **Storage**: S3-compatible object storage for journal attachments (future feature)
- ✅ **Edge Functions**: Deno-based serverless functions for backend logic (analytics, notifications)
- ✅ **Open Source**: Self-hostable, no vendor lock-in, community-driven
- ✅ **Free Tier**: Generous limits (500MB database, 50K monthly active users, 2GB bandwidth)
- ✅ **Privacy-Focused**: EU data centers available, GDPR-compliant
- ✅ **SQL Power**: Complex analytics queries (mood trends, activity correlations) built-in
- ✅ **Local Development**: Docker-based local Supabase for offline development
- ✅ **Automatic REST API**: Database tables auto-generate RESTful endpoints with OpenAPI docs
- ✅ **Dashboard**: Admin UI for database management, user management, analytics

**Cons**:
- ⚠️ Younger platform (2020) compared to Firebase (2011) - mitigated by active development and Y Combinator backing
- ⚠️ Smaller ecosystem (fewer third-party integrations) - mitigated by PostgreSQL compatibility
- ⚠️ Self-hosting requires DevOps knowledge (not needed for MVP with hosted version)

**Verdict**: Optimal balance of features, privacy, developer experience, and cost. PostgreSQL's relational model aligns perfectly with mental health data structure. RLS provides built-in security. Open-source nature prevents vendor lock-in.

---

## Consequences

### Positive

1. **Offline-First Architecture**: React Native app stores data locally (AsyncStorage + Keychain), syncs to Supabase in background. Users never blocked by network issues.

2. **Privacy by Design**: End-to-end encryption for journal entries and crisis plans implemented client-side. Supabase stores encrypted blobs without ability to decrypt. Zero-knowledge architecture.

3. **Security**: Row Level Security (RLS) policies enforce data isolation at database level. Users cannot access other users' data even if client-side checks fail.

4. **Developer Experience**: Supabase TypeScript SDK auto-generates types from database schema. No manual API client code needed. Excellent TypeScript IntelliSense.

5. **Cost-Effective**: Free tier supports MVP with up to 50K monthly active users. Paid tier starts at $25/month (Pro plan) with predictable pricing.

6. **Scalability**: PostgreSQL scales vertically (larger instances) and horizontally (read replicas). Supabase handles infrastructure automatically.

7. **Real-time Optional**: WebSocket subscriptions available for family exercise notifications without additional infrastructure.

8. **Analytics Built-In**: SQL analytics queries run directly on PostgreSQL. No need for separate analytics database.

9. **Self-Hosting Path**: If Supabase costs become prohibitive or specific customizations needed, self-hosting is possible (Docker Compose setup).

10. **Local Development**: Docker-based local Supabase environment mirrors production. No cloud dependency for development.

### Negative

1. **Platform Learning Curve**: Team must learn Supabase-specific concepts (RLS policies, PostgREST API conventions, edge functions). Mitigated by excellent documentation.

2. **PostgreSQL Complexity**: SQL requires more upfront schema design than NoSQL. Mitigated by LitmonCloud's Model-first approach and Zod validation schemas.

3. **Migration Risk**: If Supabase discontinued, migration to self-hosted or different PostgreSQL backend required. Mitigated by open-source nature and standard PostgreSQL compatibility.

4. **Real-time Limitations**: Realtime subscriptions count against connection limits. MVP uses polling instead; real-time is optional enhancement.

### Neutral

1. **Testing**: Mock Supabase server required for unit tests. Standard practice with any backend platform.

2. **Type Safety**: Supabase TypeScript SDK provides runtime type safety, complementing Zod validation on client.

---

## Implementation Strategy

### Phase 1: Database Schema Design (Week 1)

**Tables**:
- `auth.users` (managed by Supabase Auth)
- `conversation_prompts` (daily prompts)
- `prompt_responses` (user responses)
- `mood_entries` (daily mood tracking)
- `journal_entries` (encrypted therapeutic journal)
- `family_exercises` (exercise library)
- `exercise_completions` (user progress)
- `crisis_plans` (encrypted safety plans)
- `emergency_resources` (hotlines, clinics)

**RLS Policies**:
```sql
-- Example: Mood entries RLS
ALTER TABLE mood_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own mood entries"
  ON mood_entries
  FOR ALL
  USING (auth.uid() = user_id);
```

### Phase 2: Authentication Integration (Week 2)

**Sign in with Apple**:
```typescript
import { supabase } from '@/services/SupabaseClient';
import { appleAuth } from '@invertase/react-native-apple-authentication';

const { identityToken } = await appleAuth.performRequest({
  requestedOperation: appleAuth.Operation.LOGIN,
  requestedScopes: [appleAuth.Scope.EMAIL]
});

const { data, error } = await supabase.auth.signInWithIdToken({
  provider: 'apple',
  token: identityToken
});
```

**Anonymous Authentication** (for trial users):
```typescript
const { data, error } = await supabase.auth.signUp({
  email: `anon_${uuidv4()}@rediscovertalk.app`,
  password: crypto.randomBytes(32).toString('hex')
});
```

### Phase 3: Repository Pattern (Week 3-4)

**Local-First Data Access**:
```typescript
// src/features/wellness/repositories/MoodEntryRepository.ts
export class MoodEntryRepository {
  async create(input: CreateMoodEntryInput): Promise<MoodEntry> {
    // 1. Save locally (AsyncStorage)
    const entry = await this.saveLocal(input);

    // 2. Add to sync queue
    await this.syncQueue.add('mood_entry', 'create', entry);

    // 3. Return immediately (optimistic UI)
    return entry;
  }

  async getAll(): Promise<MoodEntry[]> {
    // 1. Fetch from local storage (fast)
    const local = await this.fetchLocal();

    // 2. Background sync from Supabase
    this.backgroundSync();

    return local;
  }
}
```

### Phase 4: Background Sync (Week 5)

**Sync Service**:
```typescript
// src/core/services/SyncService.ts
export class SyncService {
  async processSyncQueue(): Promise<void> {
    const queue = await this.getSyncQueue();

    for (const item of queue) {
      try {
        await this.syncToSupabase(item);
        await this.markSynced(item.id);
      } catch (error) {
        await this.incrementRetryCount(item.id);
      }
    }
  }
}
```

### Phase 5: Real-time (Optional, Post-MVP)

**WebSocket Subscriptions**:
```typescript
const channel = supabase
  .channel('exercise_completions')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'exercise_completions'
  }, payload => {
    console.log('New exercise completed:', payload.new);
  })
  .subscribe();
```

---

## Security Architecture

### Data Classification

| Data Type | Storage | Encryption | RLS Policy |
|-----------|---------|------------|------------|
| User Profile | Supabase `auth.users` | TLS in transit | Built-in |
| Mood Entries | Supabase `mood_entries` | TLS in transit | User-scoped |
| Journal Entries | Supabase `journal_entries` | AES-256 client-side + TLS | User-scoped |
| Crisis Plans | Supabase `crisis_plans` | AES-256 client-side + TLS | User-scoped |
| Conversation Prompts | Supabase `conversation_prompts` | TLS in transit | Public read |

### Encryption Flow

**Journal Entry Creation**:
```
User Input (plaintext)
        ↓
AES-256 Encryption (client-side with user key)
        ↓
Base64 Encode (encrypted ciphertext)
        ↓
Store in Local Keychain (encrypted)
        ↓
Sync to Supabase (TLS in transit)
        ↓
PostgreSQL Storage (encrypted blob)
```

**Server Cannot Decrypt**: Encryption keys stored only in device Keychain, never transmitted to server.

---

## Cost Analysis

### Free Tier (MVP - First 6 Months)

**Limits**:
- 500 MB database storage
- 1 GB file storage
- 2 GB bandwidth
- 50,000 monthly active users
- Unlimited API requests
- Unlimited edge function invocations (2M free)

**MVP Usage Estimates**:
- Database: ~100 MB (1,000 users × 100 KB average data)
- File Storage: ~500 MB (journal attachments, future feature)
- Bandwidth: ~1 GB (API requests + file downloads)
- Active Users: ~2,000 (early adopters)

**Verdict**: Free tier sufficient for MVP launch and early growth.

### Pro Tier ($25/month - Months 7-12)

**Limits**:
- 8 GB database storage (16x free tier)
- 100 GB file storage (100x free tier)
- 250 GB bandwidth (125x free tier)
- 100,000 monthly active users (2x free tier)
- Daily backups (Point-in-time recovery)
- Email support

**Post-MVP Usage Estimates**:
- Database: ~2 GB (20,000 users × 100 KB)
- Bandwidth: ~50 GB
- Active Users: ~10,000

**Verdict**: Pro tier supports growth to 20K users for $25/month.

### Comparison with Alternatives

| Platform | Free Tier | Paid Tier | 10K Users Cost |
|----------|-----------|-----------|----------------|
| Supabase | 500 MB, 50K users | $25/mo (8GB, 100K) | $25/mo |
| Firebase | 1 GB, unlimited | Pay-as-you-go | ~$100/mo (est.) |
| AWS Amplify | None | Pay-as-you-go | ~$200/mo (est.) |
| Custom Backend | None | $50/mo (hosting) | $150/mo (hosting + maintenance) |

**Winner**: Supabase provides best cost-to-value ratio with predictable pricing.

---

## Compliance

### HIPAA-Compliance Readiness

**Technical Safeguards**:
- ✅ Encryption at rest (PostgreSQL encryption)
- ✅ Encryption in transit (TLS 1.3)
- ✅ Access controls (RLS policies, JWT tokens)
- ✅ Audit logging (Supabase dashboard, PostgreSQL logs)
- ✅ Automatic backups (Pro tier)
- ✅ Data export (PostgreSQL dump)

**Administrative Safeguards**:
- ✅ BAA (Business Associate Agreement) available on Pro tier
- ✅ GDPR compliance (EU data centers available)
- ✅ Data retention policies (user-controlled)

**Note**: Full HIPAA compliance requires Pro tier + BAA + additional security reviews. MVP focuses on technical readiness.

---

## Migration Strategy

### Exit Plan (If Needed)

**Scenario**: Supabase discontinues service or costs become prohibitive.

**Migration Options**:
1. **Self-Hosted Supabase**: Deploy Supabase stack on AWS/GCP/DigitalOcean using Docker Compose
2. **Standard PostgreSQL**: Migrate to managed PostgreSQL (AWS RDS, Google Cloud SQL) + custom REST API
3. **Alternative BaaS**: Migrate to similar platform (Nhost, PocketBase) with PostgreSQL compatibility

**Data Export**:
```bash
# PostgreSQL dump
pg_dump -h db.supabase.co -U postgres -d rediscover_talk > backup.sql

# Restore to new PostgreSQL instance
psql -h new-db-host -U postgres -d rediscover_talk < backup.sql
```

**Client SDK Migration**:
- Supabase client uses standard `fetch` API and WebSockets
- Repository pattern abstracts Supabase-specific code
- Swap `supabase.from('table')` with custom REST client

**Estimated Migration Effort**: 2-4 weeks (depending on destination platform)

---

## References

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Sign in with Apple Integration](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [LitmonCloud Offline-First Architecture](../../ARCHITECTURE.md)

---

## Review & Approval

**Approved By**: Enterprise Architect, Backend Specialist, iOS Backend Integration Specialist
**Security Review**: Passed
**Privacy Review**: Passed
**Cost Review**: Approved for MVP budget
**Review Date**: 2025-10-21
**Next Review**: 2025-11-21 (Monthly - Critical Dependency)
