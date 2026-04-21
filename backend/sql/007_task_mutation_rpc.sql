-- Supabase SQL #7: atomic + idempotent task mutations

create table if not exists public.task_mutation_idempotency (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  idempotency_key text not null,
  action text not null,
  request_payload jsonb not null default '{}'::jsonb,
  response_payload jsonb not null,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create index if not exists idx_task_mutation_idempotency_user_created
  on public.task_mutation_idempotency (user_id, created_at desc);

create or replace function public.apply_task_mutation(
  p_user_id text,
  p_idempotency_key text,
  p_action text,
  p_task_id uuid default null,
  p_domain text default null,
  p_title text default null,
  p_subtitle text default null,
  p_estimate text default null,
  p_priority int default null,
  p_due_at timestamptz default null,
  p_source text default null,
  p_actor text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
  v_action text := lower(trim(coalesce(p_action, '')));
  v_actor text := lower(trim(coalesce(p_actor, 'user')));
  v_domain text := lower(trim(coalesce(p_domain, '')));
  v_source text := lower(trim(coalesce(p_source, 'manual')));
  v_status text := 'ok';
  v_rows int := 0;
  v_task public.coaching_tasks%rowtype;
  v_payload jsonb;
  v_existing jsonb;
begin
  if p_user_id is null or btrim(p_user_id) = '' then
    raise exception using errcode = '22023', message = 'p_user_id is required';
  end if;

  if p_idempotency_key is null or length(btrim(p_idempotency_key)) < 8 then
    raise exception using errcode = '22023', message = 'p_idempotency_key must be at least 8 chars';
  end if;

  if v_action not in ('create', 'complete', 'reopen', 'approve_draft', 'reject_draft', 'archive') then
    raise exception using errcode = '22023', message = 'invalid task mutation action';
  end if;

  if v_actor not in ('user', 'lock', 'system') then
    v_actor := 'user';
  end if;

  if v_source not in ('lock', 'manual') then
    v_source := 'manual';
  end if;

  select response_payload
  into v_existing
  from public.task_mutation_idempotency
  where user_id = p_user_id
    and idempotency_key = p_idempotency_key
  limit 1;

  if v_existing is not null then
    return jsonb_build_object(
      'idempotent', true,
      'status', coalesce(v_existing->>'status', 'ok'),
      'task', v_existing->'task'
    );
  end if;

  if v_action = 'create' then
    if v_domain not in ('gym', 'face', 'money', 'mind', 'social') then
      raise exception using errcode = '22023', message = 'domain is required for create';
    end if;

    if p_title is null or btrim(p_title) = '' then
      raise exception using errcode = '22023', message = 'title is required for create';
    end if;

    if p_subtitle is null or btrim(p_subtitle) = '' then
      raise exception using errcode = '22023', message = 'subtitle is required for create';
    end if;

    insert into public.coaching_tasks (
      id,
      user_id,
      domain,
      title,
      subtitle,
      estimate,
      priority,
      risk,
      state,
      source,
      due_at,
      is_completed,
      completed_at,
      created_at,
      updated_at
    ) values (
      coalesce(p_task_id, gen_random_uuid()),
      p_user_id,
      v_domain,
      p_title,
      p_subtitle,
      p_estimate,
      coalesce(p_priority, 100),
      'low',
      'active',
      v_source,
      p_due_at,
      false,
      null,
      v_now,
      v_now
    )
    returning * into v_task;

    insert into public.task_events (id, task_id, user_id, action, actor, at)
    values (gen_random_uuid(), v_task.id, p_user_id, 'created', v_actor, v_now);

    v_status := 'created';
  else
    if p_task_id is null then
      v_status := 'not_found';
    else
      select *
      into v_task
      from public.coaching_tasks
      where id = p_task_id
        and user_id = p_user_id
      for update;

      if not found then
        v_status := 'not_found';
      elsif v_action = 'complete' then
        if v_task.state <> 'active' then
          v_status := 'invalid_state';
        elsif v_task.is_completed then
          v_status := 'noop';
        else
          update public.coaching_tasks
          set is_completed = true,
              completed_at = v_now,
              updated_at = v_now
          where id = v_task.id
          returning * into v_task;

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'completed', v_actor, v_now);
        end if;
      elsif v_action = 'reopen' then
        if v_task.state <> 'active' then
          v_status := 'invalid_state';
        elsif not v_task.is_completed then
          v_status := 'noop';
        else
          update public.coaching_tasks
          set is_completed = false,
              completed_at = null,
              updated_at = v_now
          where id = v_task.id
          returning * into v_task;

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'reopened', v_actor, v_now);
        end if;
      elsif v_action = 'approve_draft' then
        if v_task.state <> 'draft' then
          v_status := 'invalid_state';
        else
          update public.coaching_tasks
          set state = 'active',
              updated_at = v_now
          where id = v_task.id
          returning * into v_task;

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'approved', v_actor, v_now);

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'activated', 'system', v_now);
        end if;
      elsif v_action = 'reject_draft' then
        if v_task.state <> 'draft' then
          v_status := 'invalid_state';
        else
          update public.coaching_tasks
          set state = 'archived',
              updated_at = v_now
          where id = v_task.id
          returning * into v_task;

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'rejected', v_actor, v_now);

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'archived', 'system', v_now);
        end if;
      elsif v_action = 'archive' then
        if v_task.state = 'archived' then
          v_status := 'noop';
        else
          update public.coaching_tasks
          set state = 'archived',
              updated_at = v_now
          where id = v_task.id
          returning * into v_task;

          insert into public.task_events (id, task_id, user_id, action, actor, at)
          values (gen_random_uuid(), v_task.id, p_user_id, 'archived', v_actor, v_now);
        end if;
      end if;
    end if;
  end if;

  v_payload := jsonb_build_object(
    'status', v_status,
    'task', case when v_status = 'not_found' then null else to_jsonb(v_task) end
  );

  insert into public.task_mutation_idempotency (
    user_id,
    idempotency_key,
    action,
    request_payload,
    response_payload
  ) values (
    p_user_id,
    p_idempotency_key,
    v_action,
    jsonb_build_object(
      'taskId', p_task_id,
      'domain', p_domain,
      'title', p_title,
      'subtitle', p_subtitle,
      'estimate', p_estimate,
      'priority', p_priority,
      'dueAt', p_due_at,
      'source', p_source,
      'actor', p_actor
    ),
    v_payload
  )
  on conflict (user_id, idempotency_key) do nothing;

  get diagnostics v_rows = row_count;

  if v_rows = 0 then
    select response_payload
    into v_existing
    from public.task_mutation_idempotency
    where user_id = p_user_id
      and idempotency_key = p_idempotency_key
    limit 1;

    return jsonb_build_object(
      'idempotent', true,
      'status', coalesce(v_existing->>'status', 'ok'),
      'task', v_existing->'task'
    );
  end if;

  return jsonb_build_object(
    'idempotent', false,
    'status', v_status,
    'task', v_payload->'task'
  );
end;
$$;
