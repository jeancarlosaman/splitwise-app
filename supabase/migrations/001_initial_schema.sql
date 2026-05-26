-- ============================================================
-- SplitWise App – Initial Schema
-- Run this in your Supabase project SQL Editor
-- ============================================================

-- ─── Profiles (extends auth.users) ──────────────────────────
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text unique not null,
  display_name text,
  avatar_url   text,
  created_at   timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view all profiles"
  on public.profiles for select using (auth.uid() is not null);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles(id, email, display_name)
  values (new.id, new.email, split_part(new.email, '@', 1));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─── Expense Groups ──────────────────────────────────────────
create table if not exists public.expense_groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  emoji      text default '💰',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

alter table public.expense_groups enable row level security;

-- Helper: check membership
create or replace function public.is_group_member(group_id uuid)
returns boolean language sql security definer as $$
  select exists (
    select 1 from public.group_members
    where group_members.group_id = $1
      and group_members.user_id  = auth.uid()
  );
$$;

create policy "Members can view their groups"
  on public.expense_groups for select
  using (public.is_group_member(id));

create policy "Authenticated users can create groups"
  on public.expense_groups for insert
  with check (auth.uid() = created_by);

create policy "Creator can update group"
  on public.expense_groups for update
  using (auth.uid() = created_by);

-- ─── Group Members ───────────────────────────────────────────
create table if not exists public.group_members (
  id        uuid primary key default gen_random_uuid(),
  group_id  uuid references public.expense_groups(id) on delete cascade,
  user_id   uuid references public.profiles(id) on delete cascade,
  joined_at timestamptz default now(),
  unique(group_id, user_id)
);

alter table public.group_members enable row level security;

create policy "Members can view group membership"
  on public.group_members for select
  using (public.is_group_member(group_id));

create policy "Members can add others to group"
  on public.group_members for insert
  with check (public.is_group_member(group_id) or auth.uid() = user_id);

create policy "Member can leave group"
  on public.group_members for delete
  using (auth.uid() = user_id);

-- ─── Expenses ────────────────────────────────────────────────
create table if not exists public.expenses (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references public.expense_groups(id) on delete cascade,
  description text not null,
  amount      numeric(10,2) not null,
  currency    text default 'EUR',
  paid_by     uuid references public.profiles(id) on delete set null,
  created_by  uuid references public.profiles(id) on delete set null,
  split_type  text default 'equal',  -- 'equal' | 'by_item' | 'custom'
  receipt_url text,
  created_at  timestamptz default now()
);

alter table public.expenses enable row level security;

create policy "Members can view group expenses"
  on public.expenses for select
  using (public.is_group_member(group_id));

create policy "Members can create expenses"
  on public.expenses for insert
  with check (public.is_group_member(group_id) and auth.uid() = created_by);

create policy "Creator can update expense"
  on public.expenses for update
  using (auth.uid() = created_by);

create policy "Creator can delete expense"
  on public.expenses for delete
  using (auth.uid() = created_by);

-- ─── Expense Participants ─────────────────────────────────────
create table if not exists public.expense_participants (
  id           uuid primary key default gen_random_uuid(),
  expense_id   uuid references public.expenses(id) on delete cascade,
  user_id      uuid references public.profiles(id) on delete cascade,
  share_amount numeric(10,2) not null,
  unique(expense_id, user_id)
);

alter table public.expense_participants enable row level security;

create policy "Members can view participants"
  on public.expense_participants for select
  using (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id
        and public.is_group_member(e.group_id)
    )
  );

create policy "Members can insert participants"
  on public.expense_participants for insert
  with check (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id
        and public.is_group_member(e.group_id)
    )
  );

create policy "Members can delete participants"
  on public.expense_participants for delete
  using (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id
        and public.is_group_member(e.group_id)
    )
  );

-- ─── Receipt Items (OCR) ─────────────────────────────────────
create table if not exists public.receipt_items (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid references public.expenses(id) on delete cascade,
  name        text not null,
  price       numeric(10,2) not null,
  assigned_to uuid[] default '{}'
);

alter table public.receipt_items enable row level security;

create policy "Members can view receipt items"
  on public.receipt_items for select
  using (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id
        and public.is_group_member(e.group_id)
    )
  );

create policy "Members can insert receipt items"
  on public.receipt_items for insert
  with check (
    exists (
      select 1 from public.expenses e
      where e.id = expense_id
        and public.is_group_member(e.group_id)
    )
  );

-- ─── Storage bucket (receipts) ───────────────────────────────
-- Run manually in the Supabase dashboard: Storage > New Bucket
-- Name: receipts, Private: true
-- Or via the CLI:
-- supabase storage buckets create receipts --private
