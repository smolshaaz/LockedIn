# Supabase Setup SQL (Postgres + pgvector)

Run these in Supabase SQL Editor in this order:

1. `001_extensions.sql`
2. `002_core_schema.sql`
3. `003_vector_functions.sql`
4. `004_rls_policies.sql` (optional but recommended)
5. `005_profile_onboarding_payload.sql` (run for existing projects; included in fresh `002_core_schema.sql`)
6. `006_task_domain_guardrails.sql` (recommended for existing projects to backfill and enforce Maxx task domains)
7. `007_task_mutation_rpc.sql` (recommended: single atomic + idempotent mutation function for all task writes)

## Notes

- `episodic_memories.embedding` is `vector(1536)`.
- Keep your embedding model dimension equal to `EMBEDDING_DIMENSIONS` in `.env`.
- `task_events` is append-only history; `coaching_tasks` stores latest projected state.
- `apply_task_mutation` is the SQL RPC function for atomic task writes (`POST /v1/tasks/mutate`).
- `match_episodic_memories` is the SQL RPC function for similarity recall.
- `004_rls_policies.sql` intentionally uses `drop policy if exists + create policy` for compatibility with Supabase Postgres versions that do not support `create policy if not exists`.
