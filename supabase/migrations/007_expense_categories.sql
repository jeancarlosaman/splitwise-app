-- Optional category for expenses. Used by the personal-group "Categories"
-- tab to break down spending. Kept as free-text so the user can add their
-- own categories later without a schema migration.

alter table public.expenses
  add column if not exists category text;

create index if not exists expenses_category_idx
  on public.expenses (category)
  where category is not null;
