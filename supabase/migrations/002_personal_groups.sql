-- Adds a flag to expense_groups so we can distinguish the auto-created
-- "Personal" group (single-user, hidden as a special tile) from regular
-- shared groups.
alter table public.expense_groups
  add column if not exists is_personal boolean not null default false;

-- A user should only ever have one personal group.
create unique index if not exists expense_groups_one_personal_per_user
  on public.expense_groups (created_by)
  where is_personal = true;
