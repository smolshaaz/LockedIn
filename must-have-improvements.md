# Must-Have Improvements (Post-MVP)

## Current Status (OK for now)
- Render backend is live.
- Supabase is connected.
- Gemini key is configured.
- Upstash Redis is intentionally skipped (acceptable for single-channel iOS MVP).

## Must-Have Next (Production Hardening)

1. Auth and user identity
- Move from `AUTH_MODE=optional` to required auth.
- Use real Supabase Auth/JWT mapping to stable user IDs.
- Remove default/shared dev user behavior.

2. API safety and abuse control
- Add rate limiting per user + per IP.
- Add payload size limits and stricter request validation.
- Add domain guardrails for LOCK (reject off-purpose requests cleanly).

3. Reliability and state consistency
- Re-introduce Redis (Upstash) for thread/session state and idempotency durability.
- Add retry/backoff for external API calls (Gemini/Supabase) with circuit-breaker behavior.
- Add dead-simple fallback replies when model is unavailable.

4. Observability
- Structured logs with request IDs.
- Error tracking (Sentry or equivalent).
- Health checks plus dependency health (`db`, `model`, `cache`) endpoints.

5. Cost and quota control
- Token/request budgeting per user/day.
- Model call minimization (already partly done) with explicit caps.
- Graceful quota-exceeded UX message in app.

6. Data and security
- Rotate exposed keys immediately if ever committed.
- Enforce least-privilege env handling and secret scanning in CI.
- Add data retention and delete-account verification flows.

7. CI/CD and release quality
- CI: lint/typecheck/tests on every push.
- Staging environment before production deploy.
- Smoke tests for `/health`, `/v1/chat`, `/v1/tasks/mutate`, `/v1/maxx/:domain`.

8. Mobile app config discipline
- Keep `LOCK_API_BASE_URL` per scheme/environment (dev/staging/prod).
- Add in-app diagnostics screen (backend URL, health status, model availability).
- Remove hardcoded defaults before App Store release.

