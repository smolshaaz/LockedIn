-- Supabase SQL #2: core tables for LockedIn backend

create table if not exists public.profiles (
  user_id text primary key,
  name text not null,
  age int,
  goals text[] not null default '{}',
  constraints text[] not null default '{}',
  communication_style text not null default 'Firm',
  baseline_scores jsonb not null default '{}'::jsonb,
  onboarding_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.domain_scores_current (
  user_id text primary key,
  gym numeric(5,2) not null default 50,
  face numeric(5,2) not null default 50,
  money numeric(5,2) not null default 50,
  mind numeric(5,2) not null default 50,
  social numeric(5,2) not null default 50,
  updated_at timestamptz not null default now()
);

create table if not exists public.weekly_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  week_start date not null,
  entries jsonb not null,
  summary text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_weekly_checkins_user_week
  on public.weekly_checkins (user_id, week_start desc);

create table if not exists public.lifescore_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  week_start date not null,
  total_score numeric(5,2) not null,
  created_at timestamptz not null default now(),
  unique (user_id, week_start)
);

create index if not exists idx_lifescore_snapshots_user_week
  on public.lifescore_snapshots (user_id, week_start desc);

create table if not exists public.coaching_tasks (
  id uuid primary key,
  user_id text not null,
  domain text not null check (domain in ('gym', 'face', 'money', 'mind', 'social')),
  title text not null,
  subtitle text not null,
  estimate text,
  priority int not null default 100,
  risk text not null check (risk in ('low', 'medium', 'high')),
  state text not null check (state in ('draft', 'active', 'archived')),
  source text not null check (source in ('lock', 'manual')),
  due_at timestamptz,
  is_completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create index if not exists idx_coaching_tasks_user_state
  on public.coaching_tasks (user_id, state, priority asc);

create index if not exists idx_coaching_tasks_user_domain_state
  on public.coaching_tasks (user_id, domain, state, priority asc);

create table if not exists public.task_events (
  id uuid primary key,
  task_id uuid not null references public.coaching_tasks(id) on delete cascade,
  user_id text not null,
  action text not null check (action in ('created', 'approved', 'rejected', 'activated', 'archived', 'completed', 'reopened')),
  actor text not null check (actor in ('user', 'lock', 'system')),
  at timestamptz not null
);

create index if not exists idx_task_events_task_at
  on public.task_events (task_id, at desc);

create index if not exists idx_task_events_user_at
  on public.task_events (user_id, at desc);

create table if not exists public.episodic_memories (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  summary text not null,
  tags text[] not null default '{}',
  embedding vector(1536) not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_episodic_memories_user_created
  on public.episodic_memories (user_id, created_at desc);

create index if not exists idx_episodic_memories_embedding_hnsw
  on public.episodic_memories
  using hnsw (embedding vector_cosine_ops);
