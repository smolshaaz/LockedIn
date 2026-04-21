-- Supabase SQL #4: optional RLS policies for client-side access patterns
-- If you only use service-role key from backend, service role bypasses RLS.

alter table public.profiles enable row level security;
alter table public.domain_scores_current enable row level security;
alter table public.weekly_checkins enable row level security;
alter table public.lifescore_snapshots enable row level security;
alter table public.coaching_tasks enable row level security;
alter table public.task_events enable row level security;
alter table public.episodic_memories enable row level security;

drop policy if exists profiles_own_select on public.profiles;
create policy profiles_own_select on public.profiles
for select using (user_id = auth.uid()::text);

drop policy if exists profiles_own_upsert on public.profiles;
create policy profiles_own_upsert on public.profiles
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists domain_scores_own_access on public.domain_scores_current;
create policy domain_scores_own_access on public.domain_scores_current
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists weekly_checkins_own_access on public.weekly_checkins;
create policy weekly_checkins_own_access on public.weekly_checkins
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists lifescore_own_access on public.lifescore_snapshots;
create policy lifescore_own_access on public.lifescore_snapshots
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists tasks_own_access on public.coaching_tasks;
create policy tasks_own_access on public.coaching_tasks
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists task_events_own_access on public.task_events;
create policy task_events_own_access on public.task_events
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);

drop policy if exists episodic_own_access on public.episodic_memories;
create policy episodic_own_access on public.episodic_memories
for all using (user_id = auth.uid()::text)
with check (user_id = auth.uid()::text);
