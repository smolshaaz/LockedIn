-- Supabase SQL #6: enforce Maxx domain ownership on coaching tasks

update public.coaching_tasks
set domain = case
  when concat_ws(' ', title, subtitle) ~* '(gym|workout|bench|squat|protein|training|cardio)' then 'gym'
  when concat_ws(' ', title, subtitle) ~* '(skin|face|spf|jaw|groom|acne|hydration)' then 'face'
  when concat_ws(' ', title, subtitle) ~* '(money|income|job|internship|application|pipeline|portfolio)' then 'money'
  when concat_ws(' ', title, subtitle) ~* '(social|confidence|approach|conversation|network|follow-up)' then 'social'
  else 'mind'
end
where domain is null
  or lower(domain) not in ('gym', 'face', 'money', 'mind', 'social')
  or domain <> lower(domain);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'coaching_tasks_domain_check'
      and conrelid = 'public.coaching_tasks'::regclass
  ) then
    alter table public.coaching_tasks
      add constraint coaching_tasks_domain_check
      check (domain in ('gym', 'face', 'money', 'mind', 'social'));
  end if;
end
$$;

alter table public.coaching_tasks
  alter column domain set not null;

