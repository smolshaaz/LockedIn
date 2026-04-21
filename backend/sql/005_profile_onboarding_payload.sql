-- Supabase SQL #5: preserve full onboarding payload for AI context

alter table public.profiles
  add column if not exists onboarding_payload jsonb not null default '{}'::jsonb;

alter table public.profiles
  alter column communication_style set default 'Firm';
