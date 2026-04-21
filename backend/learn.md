# LockedIn Backend Learn Guide (0 -> Present)

This document explains how we moved from a basic backend skeleton to the current architecture.
It is written as if a human engineer is starting with empty files and deciding what to write next.

Scope: backend only (`backend/src/*`, `backend/tests/*`).

## 1) What We Wanted Before Writing Code

We agreed on these goals:

1. Keep existing API contracts stable for the Swift app (`/v1/profile`, `/v1/checkins/weekly`, `/v1/lifescore`, `/v1/chat`).
2. Add unified tasks so Home and Protocols read/write the same task truth.
3. Use append-only task events (not only mutable boolean flags).
4. Support chat streaming (`/v1/chat/stream`) and still support JSON chat (`/v1/chat`).
5. Keep auth easy in dev, stricter in production mode.
6. Keep routes thin and push behavior into services.

If you keep those 6 goals visible, almost every line in the codebase becomes easy to justify.

## 2) The Core Engineering Rule Used Everywhere

For each file, we followed this sequence:

1. Write one sentence: "what single responsibility does this file own?"
2. Identify inputs and outputs.
3. Add guard clauses for invalid paths first.
4. Keep happy path shallow.
5. Delegate complex logic to services.

This is why you keep seeing `if (!parsed.success) return badRequest(...)` style guards.

## 3) Build Order We Followed

We did not write random files. The order was deliberate:

1. `schemas/contracts.ts` (shared shapes and validation)
2. `config/env.ts` (runtime policy)
3. `services/auth-service.ts` (token-to-user resolution)
4. `middleware/auth.ts` (request-level identity gate)
5. `services/*` (domain logic)
6. `routes/*` (HTTP transport only)
7. `index.ts` (app wiring)
8. `tests/*` (prove behavior)

Why this order: contracts first avoids route/service mismatch; auth boundary early avoids rewriting every route later.

## 4) File-By-File Walkthrough (Why + How + Line-Level)

## 4.1 `src/schemas/contracts.ts`

Path: `backend/src/schemas/contracts.ts`

### Why this file exists

- It is the backend API contract source-of-truth.
- It defines runtime validation with Zod.
- It exports TypeScript types inferred from those schemas.

Without this file, every route would do ad-hoc validation and contracts would drift.

### Blank-file thought process

If this file were empty, first question is: "what payloads cross the API boundary?"

Answer:
- profile onboarding and updates
- chat request/response
- weekly check-in
- lifescore response
- task APIs (queue, events, draft decisions)

So we model each with `z.object(...)`.

### Line-level map

- `1-2`: import `z` and domain enum source (`MAXX_DOMAINS`).
- `4`: base enum schema for domain values. This prevents string typos like `mindd`.
- `6-21`: profile schemas.
  - `profileSchema`: full shape for onboarding.
  - `updateProfileSchema`: partial shape, but with `.refine(...)` so empty patch is rejected.
- `23-27`: context flags for chat routing and protocol generation.
- `29-41`: protocol object shape.
- `43-53`: task enums (`risk`, `state`, `event action`) so task logic is finite and explicit.
- `55-69`: full task projection shape returned to clients.
- `71-77`: append-only task event record shape.
- `79-88`: task queue and task sync response envelopes.
- `90-96`: coach reply now includes optional `taskSync` because protocol generation can create tasks.
- `98-102`: chat request.
- `104-123`: check-in request and progress shape.
- `125-136`: lifescore breakdown with trend points.
- `138-144`: tiny command schemas for task mutations.
- `146-160`: `z.infer` exports used by services/routes.

### Why so many enums and schemas

Because this backend is moving to more surfaces (web + bots + iOS). Strong schema boundaries prevent subtle breakage when one surface changes.

## 4.2 `src/config/env.ts`

Path: `backend/src/config/env.ts`

### Why this file exists

- Centralized process configuration.
- Validates env vars at startup.
- Exposes clean booleans like `isAuthOptional`.

### Blank-file thought process

Question: "What runtime knobs does backend need now?"

Current answer:
- `AUTH_MODE`, model timeout, optional redis/supabase URLs.

### Line-level map

- `1`: import zod.
- `3-10`: declare env schema with defaults.
- `12`: parse `process.env` once.
- `14`: derive boolean used directly in middleware.

### Why not read `process.env` in every file

You can, but it duplicates parsing, duplicates defaults, and creates typo risk.

## 4.3 `src/services/auth-service.ts`

Path: `backend/src/services/auth-service.ts`

### Why this file exists

- It isolates token verification mechanics from middleware policy.
- Middleware decides "required vs optional".
- Service decides "header -> user id or null".

### Line-level map

- `1`: class wrapper so later we can inject real verification provider.
- `2`: async signature now, because real token verification will be async.
- `3-5`: guard invalid/absent bearer format.
- `7-10`: parse and minimal token sanity check.
- `12`: return normalized internal user id string.

### Why async even when simple now

To avoid later breaking changes when switching to real JWT verification.

## 4.4 `src/middleware/auth.ts`

Path: `backend/src/middleware/auth.ts`

### Why this file exists

- Every route needs a `userId` identity context.
- This file ensures identity exists before handlers execute.

### Blank-file thought process

Write decision table first:

- optional mode: `X-User-Id` OR bearer OR default `dev-user`
- required mode: valid bearer only

Then write guard-first code.

### Line-level map

- `1-4`: imports.
- `6-10`: Hono context type augmentation so `c.get("userId")` is typed.
- `12`: middleware function.
- `13-15`: collect identity candidates.
- `17-21`: optional mode short-circuit (dev convenience).
- `23-25`: required mode rejection path.
- `27`: set resolved user id.
- `29`: continue to route.

### Why no deep `else` nesting

Early returns keep auth control flow readable and safer.

## 4.5 `src/services/model-router-service.ts`

Path: `backend/src/services/model-router-service.ts`

### Why this file exists

- Central policy for model selection.
- Prevents model routing rules from leaking across files.

### Line-level map

- `3`: finite model names.
- `5-10`: task-level routing (`checkin/summary` cheaper model).
- `12-21`: chat routing based on protocol/deep-work cues.
- `23-25`: deterministic fallback route.

## 4.6 `src/services/coach-service.ts`

Path: `backend/src/services/coach-service.ts`

### Why this file exists

- Encapsulates coaching response generation.
- Keeps routes transport-only.

### Line-level map

- `9-37`: `buildProtocol` helper; deterministic protocol skeleton.
- `39-44`: service API shape.
- `45`: choose model first.
- `47-56`: build profile+memory context lines.
- `57-63`: build final message.
- `64-72`: return response, optionally add protocol.
- `73-81`: failure fallback response.

### Why `try/catch`

Protect route from upstream failures and always return stable response shape.

## 4.7 `src/services/memory-service.ts`

Path: `backend/src/services/memory-service.ts`

This is the largest file. It combines in-memory adapters for:
- profile memory
- check-ins
- lifescore snapshots
- episodic recall
- unified tasks + append-only events

### Why this file exists

Because we have not yet plugged real Postgres/Redis/pgvector adapters.
This class currently emulates that architecture in process memory while preserving behavior and contracts.

### High-level structure

- Types and constants (`1-52`)
- pure helpers (`53-116`)
- `MemoryService` with grouped methods (`118-540`)

### Detailed walkthrough by block

#### A) Internal storage types

- `15-19` `ChatTurn`: one message in thread history.
- `21-27` `EpisodicMemory`: summary + tags + vector.
- `29` `StoredTask`: internal task shape without derived completion fields.
- `31-46` `UserMemory`: everything kept per user.

Why: one per-user state object avoids scattering state across maps.

#### B) Limits and helper functions

- `48-51`: bounded memory capacities.
- `53-55`: `nowISO()` timestamp helper.
- `57-65`: `defaultScores()` fallback baseline.
- `67-73`: tokenizer for lexical recall.
- `75-87`: task risk heuristic from protocol text.
- `89-97`: local fake embedding function.
- `99-116`: cosine similarity.

Why include vector-ish code now: maintain same architecture shape before real pgvector.

#### C) Service initialization and safe user creation

- `118-119`: in-memory map store.
- `121-141` `ensureUser`: lazy-create user bucket if missing.

This is a standard adapter pattern: all methods call `ensureUser` first so no null chaos.

#### D) Task event and projection internals

- `143-151`: `appendTaskEvent` appends immutable event records.
- `153-170`: derive completion state from event stream (`completed`/`reopened`).
- `172-178`: merge stored task + derived completion into API task projection.

This is the key event-sourcing idea in this file.

#### E) Recall and trust heuristics internals

- `180-193`: combined lexical + vector recall score.
- `195-200`: trust/risk auto-activation policy.
- `202-207`: trust score formula.
- `209-222`: archive existing lock tasks for domain when new protocol is generated.

#### F) Profile and score methods

- `224-255`: get/set/merge profile + domain score sync.
- `257-286`: ingest weekly check-in and create summary memory.
- `288-301`: store snapshot by week (upsert + bounded list).
- `303-309`: trend read projection.

#### G) Chat/session memory

- `311-333`: append user and assistant turns; update thread counters; store episodic summary.
- `335-349`: persist episodic summary with generated embedding.
- `351-371`: recall top relevant summaries.

#### H) Unified task system

- `373-430` `createTasksFromProtocol`:
  - archive prior lock tasks
  - generate new tasks
  - append creation events
  - auto-activate based on trust/risk
  - return `taskSync` payload
- `432-455` home queue projection (latest completed + active tasks)
- `457-463` protocol task projection
- `465-471` draft task projection
- `473-491` append completion/reopen events on active tasks
- `493-533` draft approve/reject flow and trust updates
- `535-539` task event query helper

### Why this style (many small methods)

Because this class has multiple concerns. Small internal methods prevent one giant unreadable function.

## 4.8 `src/routes/chat-routes.ts`

Path: `backend/src/routes/chat-routes.ts`

### Why this file exists

- Exposes chat as HTTP.
- Keeps transport concerns (request parsing, response format).
- Delegates behavior to services.

### Blank-file thought process

We needed two endpoints sharing same domain logic.
So first create internal `runChat(...)`, then mount two routes (`/` and `/stream`) that call it.

### Line-level map

- `1-5`: imports.
- `7-9`: route instance + auth middleware.
- `11-43` `runChat`:
  - validate payload (`safeParse`)
  - fetch profile + recall
  - generate coach reply
  - append chat memory
  - if protocol exists, sync tasks
  - return result union (`ok` true/false)
- `45-55`: JSON endpoint.
- `57-108`: SSE endpoint.
  - splits message into token-like chunks
  - emits `meta`, `token`, optional `protocol`, optional `tasks`, then `done`
  - sets `text/event-stream` headers

### Why `runChat` returns union object instead of throwing

Because route handlers can branch cleanly and keep response shape explicit without exception-heavy control flow.

## 4.9 `src/routes/tasks-routes.ts`

Path: `backend/src/routes/tasks-routes.ts`

### Why this file exists

This is the HTTP layer for unified task projections and mutations.

### Line-level map

- `1-10`: imports.
- `11-13`: route + auth.
- `15-19`: home queue projection endpoint.
- `21-25`: drafts endpoint.
- `27-40`: protocol-specific active tasks endpoint.
- `42-64`: append task event endpoint (completed/reopened).
- `66-88`: draft decision endpoint (approve/reject).

### Why validation is repeated in routes

Because transport boundary is where malformed input must be rejected immediately.

## 4.10 `src/routes/checkin-routes.ts`

Path: `backend/src/routes/checkin-routes.ts`

### Why this file changed

To support hybrid LifeScore history:
- check-in remains source-of-truth input
- snapshots are persisted
- trend then includes persisted points

### Line-level map

- `13-20`: parse and validate request.
- `22-24`: compute check-in delta.
- `26-30`: compute current score and persist weekly snapshot.
- `32-35`: recompute with updated trend projection.
- `37-40`: return progress + lifeScore.

Why compute twice: first to store accurate snapshot, second to return trend including the new snapshot.

## 4.11 `src/routes/lifescore-routes.ts`

Path: `backend/src/routes/lifescore-routes.ts`

Simple read endpoint:
- auth
- compute from domain scores + trend snapshots
- return JSON

## 4.12 `src/routes/profile-routes.ts`

Path: `backend/src/routes/profile-routes.ts`

This remained mostly stable.
It already followed desired pattern:
- validate input
- keep handlers thin
- delegate to service

## 4.13 `src/index.ts`

Path: `backend/src/index.ts`

### Why this file exists

Single app composition root.
If this file is clean, route registration and middleware chain are obvious.

### Line-level map

- `1-7`: import framework and route modules.
- `9`: app instance.
- `11-18`: CORS policy.
- `20-21`: root + health probes.
- `23-27`: mount versioned route groups.
- `29`: export app.

## 4.14 `src/utils/http.ts`

Path: `backend/src/utils/http.ts`

Centralized small response helpers:
- `badRequest`
- `unauthorized`
- `notFound`

Why this matters: avoids duplicate inline error response shapes.

## 5) How One Request Flows (Concrete)

## 5.1 Chat JSON flow (`POST /v1/chat`)

1. `index.ts` routes to `chatRoutes`.
2. `authMiddleware` resolves `userId`.
3. route parses body and calls `runChat`.
4. `runChat` validates with `chatRequestSchema`.
5. `MemoryService` recalls episodic summaries.
6. `CoachService` generates reply (+ optional protocol).
7. `MemoryService` appends chat turns.
8. if protocol exists, tasks are generated/synced.
9. route returns JSON reply.

## 5.2 Chat stream flow (`POST /v1/chat/stream`)

Same domain flow as JSON, then transport differs:
- response emitted as SSE events (`meta`, `token`, `protocol`, `tasks`, `done`).

## 5.3 Check-in flow (`POST /v1/checkins/weekly`)

1. validate body
2. ingest check-in
3. compute per-domain deltas
4. compute current lifescore
5. persist weekly snapshot
6. compute response with refreshed trend

## 6) Why `if` Statements Are Everywhere

In this codebase, `if` mostly does one of 3 jobs:

1. Guard invalid input early (`if !parsed.success return ...`)
2. Branch business rule (`if state === "draft"`)
3. Optional behavior (`if reply.suggestedProtocol`)

This is not noise. It is explicit control flow at boundaries.

## 7) Why Some Blocks Do Not Use `else`

Pattern used heavily:

```ts
if (invalid) return error
if (otherInvalid) return error
// happy path
```

Reason: fewer nested scopes, easier reading, less accidental fall-through.

## 8) What Is Still Temporary (Honest Technical Debt)

Current state is behavior-complete but storage/auth adapters are simplified.

Temporary adapters:
- in-process `MemoryService` instead of Postgres/Redis/pgvector implementations
- `AuthService.verifyToken` is placeholder logic

Not temporary:
- file boundaries
- route/service split
- contract-driven validation
- unified task + append-only event model

So the architecture is not wasted; only adapter internals are meant to be swapped.

## 9) Tests That Prove Current Behavior

Paths:
- `backend/tests/api.integration.test.ts`
- `backend/tests/memory.test.ts`
- `backend/tests/model-router.test.ts`
- `backend/tests/lifescore.test.ts`

What was added:
- unified task sync behavior
- draft approve flow
- completion event behavior
- streaming endpoint behavior
- lifescore trend snapshot assertion

## 10) "Empty File" Template You Can Reuse

When you open a blank backend file, do this in order:

1. Write one responsibility sentence at top (in your head or comment).
2. List input values this file receives.
3. List output values it must produce.
4. Write invalid-path guards first.
5. Write happy path second.
6. Extract heavy logic into helper/service if function exceeds easy readability.
7. Add one test per branch.

If you follow this, you will stop feeling stuck at blank files.

## 11) Next Learning Move (Recommended)

Take one file at a time and rewrite it from scratch in a throwaway branch:

1. `auth.ts`
2. `chat-routes.ts`
3. `tasks-routes.ts`
4. subset of `memory-service.ts` (`createTasksFromProtocol`, `recordTaskEvent`, `decideDraftTask`)

This order gives fastest understanding gain because each step builds directly on the previous one.


## 12) Literal Code Statements (No Line-Number Dependency)

You asked for exact statements instead of "line X" references. This section does that.

## 12.1 Auth Middleware (Exact Statements + Why)

Path: `backend/src/middleware/auth.ts`

```ts
const header = c.req.header("authorization")
```
Why: read bearer token input from request headers.

```ts
const fallbackUser = c.req.header("x-user-id")
```
Why: dev/testing fallback identity when auth is optional.

```ts
const resolvedFromBearer = await services.auth.verifyToken(header)
```
Why: delegate token parsing/verification to auth service; middleware should not implement token mechanics.

```ts
if (isAuthOptional) {
  c.set("userId", fallbackUser ?? resolvedFromBearer ?? "dev-user")
  await next()
  return
}
```
Why: in optional mode we always set a usable user id and continue.

```ts
if (!resolvedFromBearer) {
  return unauthorized(c)
}
```
Why: in required mode bearer verification must succeed; otherwise stop early with 401.

```ts
c.set("userId", resolvedFromBearer)
await next()
```
Why: happy path in strict mode.

## 12.2 Auth Service (Exact Statements + Why)

Path: `backend/src/services/auth-service.ts`

```ts
if (!authorizationHeader?.startsWith("Bearer ")) {
  return null
}
```
Why: reject missing/malformed auth format immediately.

```ts
const token = authorizationHeader.replace("Bearer ", "").trim()
```
Why: normalize raw token.

```ts
if (token.length < 8) {
  return null
}
```
Why: tiny sanity guard to avoid nonsense tokens.

```ts
return `supabase:${token.slice(-8)}`
```
Why: temporary internal user-id derivation until real JWT/Supabase verification is wired.

## 12.3 Chat Route Core (Exact Statements + Why)

Path: `backend/src/routes/chat-routes.ts`

```ts
const parsed = chatRequestSchema.safeParse(body)
if (!parsed.success) {
  return {
    ok: false as const,
    error: parsed.error.issues[0]?.message ?? "Invalid chat payload",
  }
}
```
Why: validate transport payload before touching business logic.

```ts
const profile = services.memory.getProfile(userId)
const recalled = services.memory.recall(userId, parsed.data.message)
```
Why: gather context inputs before generating assistant output.

```ts
const reply = await services.coach.generateReply({
  request: parsed.data,
  profile,
  recalledMemory: recalled,
})
```
Why: coaching logic belongs in service, not route.

```ts
services.memory.appendChatTurn(userId, parsed.data, reply.message)
```
Why: persist session/thread memory after generating response.

```ts
if (reply.suggestedProtocol) {
  reply.taskSync = services.memory.createTasksFromProtocol({
    userId,
    plan: reply.suggestedProtocol,
    domain: parsed.data.context.domain,
  })
}
```
Why: protocol generation can mutate unified task state.

```ts
return c.json(result.reply)
```
Why: JSON chat endpoint keeps current mobile contract stable.

```ts
const words = result.reply.message.split(/\s+/).filter(Boolean)
```
Why: cheap token-like stream chunks for SSE transport.

```ts
const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
controller.enqueue(encoder.encode(payload))
```
Why: SSE framing format; each event is explicitly typed (`meta`, `token`, `done`).

## 12.4 Tasks Route Mutation Statements (Exact Statements + Why)

Path: `backend/src/routes/tasks-routes.ts`

```ts
const parsed = taskEventRequestSchema.safeParse(body)
if (!parsed.success) {
  return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid task event")
}
```
Why: enforce mutation command shape at boundary.

```ts
const updated = services.memory.recordTaskEvent({
  userId,
  taskId,
  action: parsed.data.action,
  actor: "user",
})
```
Why: route passes intent; service applies event-sourcing rules.

```ts
if (!updated) {
  return notFound(c, "Task not found or not active")
}
```
Why: do not silently succeed if task is wrong state or missing.

```ts
return c.json({ task: updated })
```
Why: return projected current state after event append.

## 12.5 Check-in Snapshot Statements (Exact Statements + Why)

Path: `backend/src/routes/checkin-routes.ts`

```ts
const previous = { ...services.memory.getDomainScores(userId) }
services.memory.ingestCheckin(userId, parsed.data)
const progress = diffCheckin(previous, parsed.data)
```
Why: we need old scores to compute delta before/after check-in.

```ts
const current = computeLifeScore(
  services.memory.getDomainScores(userId),
  services.memory.recentTrend(userId),
)
services.memory.recordLifeScoreSnapshot(userId, parsed.data.weekStart, current.totalScore)
```
Why: persist deterministic weekly snapshot.

```ts
const lifeScore = computeLifeScore(
  services.memory.getDomainScores(userId),
  services.memory.recentTrend(userId),
)
```
Why: recompute so returned trend includes the newly recorded snapshot.

## 12.6 Memory Service Task Event Statements (Exact Statements + Why)

Path: `backend/src/services/memory-service.ts`

```ts
this.appendTaskEvent(memory, {
  taskId: task.id,
  action: "created",
  actor: "lock",
})
```
Why: task creation is immutable history, not just row mutation.

```ts
if (state === "active") {
  this.appendTaskEvent(memory, {
    taskId: task.id,
    action: "activated",
    actor: "lock",
  })
}
```
Why: activation is explicit history event.

```ts
if (input.decision === "approve") {
  memory.trustSignals.approved += 1
  ...
  task.state = "active"
  ...
  return this.projectTask(memory, task)
}
```
Why: approval changes trust and transitions draft -> active.

```ts
memory.trustSignals.rejected += 1
...
task.state = "archived"
...
return this.projectTask(memory, task)
```
Why: rejection transitions draft -> archived and updates trust history.

## 12.7 Quick Rule For Your Own Writing

When you feel stuck, write these exact 4 statements first in a new route/middleware:

```ts
const body = await c.req.json().catch(() => null)
const parsed = schema.safeParse(body)
if (!parsed.success) return badRequest(c, parsed.error.issues[0]?.message ?? "Invalid payload")
```

Then add only the happy path statement(s) after that.

This removes blank-page anxiety and gives a reliable scaffold.
