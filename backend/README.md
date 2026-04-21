# LockedIn Backend

## Setup

1. Install dependencies:
   - `npm install`
2. Create env file:
   - `cp .env.example .env`
3. In Supabase SQL Editor, run files in `sql/` order:
   - `001_extensions.sql`
   - `002_core_schema.sql`
   - `003_vector_functions.sql`
   - `004_rls_policies.sql` (optional)
   - `005_profile_onboarding_payload.sql`
   - `006_task_domain_guardrails.sql`
   - `007_task_mutation_rpc.sql`
4. Fill `.env` keys for Supabase + Upstash.
5. Run API:
   - `bun run dev`

## Local Testing Bootstrap

- To seed a realistic fake profile and tasks via `POST /v1/testing/bootstrap`, set:
  - `ENABLE_TESTING_BOOTSTRAP=true` in local `.env`.
- The bootstrap route is disabled when:
  - `NODE_ENV=production`, or
  - `ENABLE_TESTING_BOOTSTRAP` is not enabled.
- To verify model wiring without sending a chat:
  - `GET /v1/testing/ai-availability`

## Persistence Modes

- `PERSISTENCE_MODE=memory`
  - uses in-process state only.
- `PERSISTENCE_MODE=mirror`
  - in-memory runtime remains active,
  - writes are mirrored to Supabase,
  - thread state is mirrored to Upstash Redis.

## Current Adapter Status

- Supabase:
  - DB-backed reads enabled for profile, scores, trends, tasks, task-events, and vector recall (RPC).
  - write mirroring implemented for profile, check-ins, snapshots, tasks, task events, episodic memory.
- Redis:
  - thread state hydrate + bump adapter implemented.

## AI SDK 6 Status

- `ai-models.ts` now resolves provider/model aliases from env:
  - `LOCK_CHAT_MODEL` (chat alias),
  - `LOCK_FAST_MODEL` (fast alias),
  - `LOCK_EMBEDDING_MODEL` (embedding model).
- Supported model providers:
  - `anthropic`
  - `openai`
  - `google` (Gemini via `GOOGLE_GENERATIVE_AI_API_KEY`)
- `CoachService` now uses AI SDK:
  - `generateText` for normal chat replies,
  - `streamText` for `/chat/stream`,
  - `generateObject` + Zod schema for protocol plans.
- `MemoryService` now attempts real `embed(...)` calls for episodic memory vectors.
- Safe fallback behavior remains:
  - if keys are missing or provider setup fails, app falls back to deterministic local behavior.

## Chat SDK Status

- Installed:
  - `chat`
  - `@chat-adapter/telegram`
  - `@chat-adapter/discord`
  - `@chat-adapter/state-redis`
- Added omnichannel webhook routes:
  - `POST /v1/omnichannel/telegram`
  - `POST /v1/omnichannel/discord`
  - `GET /v1/omnichannel/health`
- Added handler wiring:
  - `onNewMention`, `onDirectMessage`, `onSubscribedMessage` -> LOCK flow.
  - replies stream via `thread.post(stream.textStream)` when model stream is available.
- Added state fallback:
  - uses Redis state adapter when `CHAT_STATE_REDIS_URL` is provided,
  - otherwise uses in-memory state adapter.

## Engagement Automation Status

- Added backend automation endpoint:
  - `POST /v1/automation/run`
  - `GET /v1/automation/health`
- Implemented automation kinds:
  - `checkin` (weekly DM check-in prompt when due),
  - `reminder` (active protocol/task reminder),
  - `streak` (nudge when trend drops or completion signal is stale).
- Contact registry:
  - inbound omnichannel messages are tracked as automation contacts,
  - stored in Chat SDK state adapter (Redis when configured, in-memory fallback).
- Send dedupe:
  - automation sends are reserved with per-kind cooldown buckets to avoid spam.

## Next Step

Set platform keys + webhook config, then run live tests:

1. Send at least one DM/mention to register contact state.
2. Trigger `POST /v1/automation/run`.
3. Verify check-in/reminder/streak messages are delivered.

## Production Deploy (Container)

1. Build + run locally first:
   - from repo root: `docker build -f backend/Dockerfile -t lockedin-api .`
   - `docker run --rm -p 3000:3000 --env-file backend/.env lockedin-api`
2. Deploy the same container to your host (Render/Railway/Fly/any Docker host).
   - Render settings with this repo layout:
     - Dockerfile Path: `backend/Dockerfile`
     - Root Directory: leave empty (repo root context)
3. Set required env vars in host dashboard:
   - `GOOGLE_GENERATIVE_AI_API_KEY`
   - `LOCK_CHAT_MODEL=google/gemini-2.5-flash`
   - `LOCK_FAST_MODEL=google/gemini-2.5-flash`
   - `LOCK_EMBEDDING_MODEL=google/gemini-embedding-001`
   - `AUTH_MODE=optional` (or `required` once auth is wired)
   - `PERSISTENCE_MODE=mirror`
   - Supabase + Upstash keys
4. Expose HTTPS endpoint and verify:
   - `GET /health` returns `{ status: "ok" }`

## iOS App Backend URL

`LOCK_API_BASE_URL` is read from app build settings (Info.plist key injection).

- In Xcode target build settings:
  - `LOCK_API_BASE_URL=https://<your-deployed-domain>`
  - `LOCK_API_USER_ID=<stable-test-user-id>`
- The app also accepts runtime overrides:
  - launch env: `LOCK_API_BASE_URL`, `LOCK_API_USER_ID`
  - `UserDefaults` keys with same names

Do not use `127.0.0.1` for physical iPhone unless backend runs on that device.
