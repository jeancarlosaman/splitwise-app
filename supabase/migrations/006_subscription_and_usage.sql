-- Freemium tier + monthly usage tracking.
-- Free: 5 OCR scans + 5 voice parses per calendar month.
-- Pro:  unlimited. €2.99/mo.

alter table public.profiles
  add column if not exists subscription_tier text not null default 'free'
    check (subscription_tier in ('free','pro')),
  add column if not exists pro_until timestamptz;

create table if not exists public.usage_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  feature     text not null check (feature in ('ocr_scan','voice_parse')),
  created_at  timestamptz not null default now()
);

create index if not exists usage_events_user_feature_time_idx
  on public.usage_events (user_id, feature, created_at);

alter table public.usage_events enable row level security;

drop policy if exists "users see own usage" on public.usage_events;
create policy "users see own usage"
  on public.usage_events for select
  using (auth.uid() = user_id);

drop policy if exists "users insert own usage" on public.usage_events;
create policy "users insert own usage"
  on public.usage_events for insert
  with check (auth.uid() = user_id);

-- Single source of truth: returns whether the current user can use a feature
-- right now, what their usage is, and how much quota is left.
-- Pro users get unlimited (remaining = null sentinel).
create or replace function public.check_feature_quota(p_feature text, p_monthly_limit int)
returns table (
  is_pro       boolean,
  used_this_month int,
  remaining    int,
  can_use      boolean
)
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_tier    text;
  v_until   timestamptz;
  v_pro     boolean;
  v_used    int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select subscription_tier, pro_until
    into v_tier, v_until
  from profiles where id = v_user_id;

  v_pro := v_tier = 'pro' and (v_until is null or v_until > now());

  if v_pro then
    return query select true, 0, null::int, true;
    return;
  end if;

  select count(*) into v_used
  from usage_events
  where user_id = v_user_id
    and feature = p_feature
    and created_at >= date_trunc('month', now());

  return query select
    false,
    v_used,
    greatest(p_monthly_limit - v_used, 0),
    v_used < p_monthly_limit;
end $$;

grant execute on function public.check_feature_quota(text, int) to authenticated;

create or replace function public.record_feature_use(p_feature text, p_monthly_limit int)
returns table (
  is_pro       boolean,
  used_this_month int,
  remaining    int,
  can_use      boolean
)
language plpgsql security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  insert into usage_events (user_id, feature)
    values (v_user_id, p_feature);
  return query select * from check_feature_quota(p_feature, p_monthly_limit);
end $$;

grant execute on function public.record_feature_use(text, int) to authenticated;

-- STUB upgrade flow — flips the user to pro for 1 month for testing.
-- Replace with a real RevenueCat / App Store Server Notifications webhook
-- before launch so payment status comes from the verified receipt.
create or replace function public.dev_upgrade_to_pro()
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  update profiles
    set subscription_tier = 'pro',
        pro_until = now() + interval '30 days'
    where id = auth.uid();
end $$;

create or replace function public.dev_downgrade_to_free()
returns void
language plpgsql security definer
set search_path = public
as $$
begin
  update profiles
    set subscription_tier = 'free',
        pro_until = null
    where id = auth.uid();
end $$;

grant execute on function public.dev_upgrade_to_pro() to authenticated;
grant execute on function public.dev_downgrade_to_free() to authenticated;
