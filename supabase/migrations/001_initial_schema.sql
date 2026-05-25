-- ============================================================
-- SplitWise App — Initial Schema
-- Run against your Supabase project via: supabase db push
-- ============================================================

-- Enable UUID extension (usually already enabled in Supabase)
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────
-- PROFILES (extends auth.users)
-- ─────────────────────────────────────────
create table if not exists profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text unique not null,
  display_name  text,
  avatar_url    text,
  created_at    timestamptz default now()
);

-- ─────────────────────────────────────────
-- EXPENSE GROUPS
-- ─────────────────────────────────────────
create table if not exists expense_groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  emoji       text default '💰',
  created_by  uuid references profiles(id),
  created_at  timestamptz default now()
);

-- ─────────────────────────────────────────
-- GROUP MEMBERSHIPS
-- ─────────────────────────────────────────
create table if not exists group_members (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid references expense_groups(id) on delete cascade,
  user_id    uuid references profiles(id) on delete cascade,
  joined_at  timestamptz default now(),
  unique(group_id, user_id)
);

-- ─────────────────────────────────────────
-- EXPENSES
-- ─────────────────────────────────────────
create table if not exists expenses (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid references expense_groups(id) on delete cascade,
  description  text not null,
  amount       numeric(10,2) not null,
  currency     text default 'EUR',
  paid_by      uuid references profiles(id),
  created_by   uuid references profiles(id),
  created_at   timestamptz default now(),
  receipt_url  text,
  split_type   text default 'equal'  -- 'equal' | 'by_item' | 'custom'
);

-- ─────────────────────────────────────────
-- EXPENSE PARTICIPANTS
-- ─────────────────────────────────────────
create table if not exists expense_participants (
  id            uuid primary key default gen_random_uuid(),
  expense_id    uuid references expenses(id) on delete cascade,
  user_id       uuid references profiles(id) on delete cascade,
  share_amount  numeric(10,2) not null,
  unique(expense_id, user_id)
);

-- ─────────────────────────────────────────
-- RECEIPT LINE ITEMS (from OCR)
-- ─────────────────────────────────────────
create table if not exists receipt_items (
  id           uuid primary key default gen_random_uuid(),
  expense_id   uuid references expenses(id) on delete cascade,
  name         text not null,
  price        numeric(10,2) not null,
  assigned_to  uuid[]   -- array of user_ids who share this item
);

-- ─────────────────────────────────────────
-- ENABLE ROW LEVEL SECURITY
-- ─────────────────────────────────────────
alter table profiles             enable row level security;
alter table expense_groups       enable row level security;
alter table group_members        enable row level security;
alter table expenses             enable row level security;
alter table expense_participants enable row level security;
alter table receipt_items        enable row level security;

-- ─────────────────────────────────────────
-- HELPER FUNCTION: is_group_member
-- ─────────────────────────────────────────
create or replace function is_group_member(gid uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from group_members
    where group_id = gid
      and user_id  = auth.uid()
  );
$$;

-- ─────────────────────────────────────────
-- RLS POLICIES: profiles
-- ─────────────────────────────────────────
create policy "profiles_select_own"
  on profiles for select
  using (auth.uid() = id);

-- Allow users to view profiles of people in shared groups
create policy "profiles_select_group_members"
  on profiles for select
  using (
    exists (
      select 1 from group_members gm1
      join group_members gm2 on gm1.group_id = gm2.group_id
      where gm1.user_id = auth.uid()
        and gm2.user_id = profiles.id
    )
  );

create policy "profiles_insert_own"
  on profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on profiles for update
  using (auth.uid() = id);

-- ─────────────────────────────────────────
-- RLS POLICIES: expense_groups
-- ─────────────────────────────────────────
create policy "groups_select_member"
  on expense_groups for select
  using (is_group_member(id));

create policy "groups_insert_auth"
  on expense_groups for insert
  with check (auth.uid() = created_by);

create policy "groups_update_creator"
  on expense_groups for update
  using (auth.uid() = created_by);

create policy "groups_delete_creator"
  on expense_groups for delete
  using (auth.uid() = created_by);

-- ─────────────────────────────────────────
-- RLS POLICIES: group_members
-- ─────────────────────────────────────────
create policy "members_select_group"
  on group_members for select
  using (is_group_member(group_id));

-- Creator can add members; users can add themselves (via invite link)
create policy "members_insert"
  on group_members for insert
  with check (
    auth.uid() = user_id
    or exists (
      select 1 from expense_groups
      where id = group_id
        and created_by = auth.uid()
    )
  );

create policy "members_delete_self_or_creator"
  on group_members for delete
  using (
    auth.uid() = user_id
    or exists (
      select 1 from expense_groups
      where id = group_id
        and created_by = auth.uid()
    )
  );

-- ─────────────────────────────────────────
-- RLS POLICIES: expenses
-- ─────────────────────────────────────────
create policy "expenses_select_member"
  on expenses for select
  using (is_group_member(group_id));

create policy "expenses_insert_member"
  on expenses for insert
  with check (
    is_group_member(group_id)
    and auth.uid() = created_by
  );

create policy "expenses_update_creator"
  on expenses for update
  using (auth.uid() = created_by);

create policy "expenses_delete_creator"
  on expenses for delete
  using (auth.uid() = created_by);

-- ─────────────────────────────────────────
-- RLS POLICIES: expense_participants
-- ─────────────────────────────────────────
create policy "participants_select_member"
  on expense_participants for select
  using (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and is_group_member(e.group_id)
    )
  );

create policy "participants_insert_creator"
  on expense_participants for insert
  with check (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and e.created_by = auth.uid()
    )
  );

create policy "participants_delete_creator"
  on expense_participants for delete
  using (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and e.created_by = auth.uid()
    )
  );

-- ─────────────────────────────────────────
-- RLS POLICIES: receipt_items
-- ─────────────────────────────────────────
create policy "receipt_items_select_member"
  on receipt_items for select
  using (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and is_group_member(e.group_id)
    )
  );

create policy "receipt_items_insert_creator"
  on receipt_items for insert
  with check (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and e.created_by = auth.uid()
    )
  );

create policy "receipt_items_delete_creator"
  on receipt_items for delete
  using (
    exists (
      select 1 from expenses e
      where e.id = expense_id
        and e.created_by = auth.uid()
    )
  );

-- ─────────────────────────────────────────
-- TRIGGER: auto-create profile on signup
-- ─────────────────────────────────────────
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ─────────────────────────────────────────
-- STORAGE BUCKET for receipt images
-- ─────────────────────────────────────────
-- Run this in the Supabase dashboard → Storage, or via API:
-- insert into storage.buckets (id, name, public)
-- values ('receipts', 'receipts', false);
--
-- Storage RLS policy (run after creating bucket):
-- create policy "authenticated_upload"
--   on storage.objects for insert
--   with check (bucket_id = 'receipts' and auth.role() = 'authenticated');
--
-- create policy "member_read"
--   on storage.objects for select
--   using (bucket_id = 'receipts' and auth.role() = 'authenticated');
