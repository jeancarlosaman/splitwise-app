-- Friendly join codes so groups can be shared via link or copy-paste code.
-- The alphabet excludes 0/O, 1/I, L to make codes easy to read out loud.

create or replace function public.generate_join_code() returns text
language plpgsql as $$
declare
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..8 loop
    result := result ||
      substring(alphabet, (floor(random() * length(alphabet)) + 1)::int, 1);
  end loop;
  return result;
end $$;

alter table public.expense_groups
  add column if not exists join_code text unique;

update public.expense_groups
set join_code = public.generate_join_code()
where join_code is null;

alter table public.expense_groups
  alter column join_code set default public.generate_join_code();

-- SECURITY DEFINER function lets unauthenticated-against-this-group users
-- look up a group by its code and add themselves. Avoids broadening the
-- existing RLS read policy on expense_groups.
create or replace function public.join_group_by_code(p_code text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_group_id uuid;
  v_user_id  uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select id into v_group_id
  from public.expense_groups
  where upper(join_code) = upper(p_code)
    and coalesce(is_personal, false) = false;

  if v_group_id is null then
    raise exception 'invalid_code';
  end if;

  insert into public.group_members (group_id, user_id)
  values (v_group_id, v_user_id)
  on conflict do nothing;

  return v_group_id;
end $$;

grant execute on function public.join_group_by_code(text) to authenticated;
