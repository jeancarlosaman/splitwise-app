-- Enforces that the sum of expense_participants.share_amount equals
-- expenses.amount for every expense. Without this, a row with mismatched
-- shares makes DebtSimplifier silently return empty (no positive balances
-- to pair against debts), which hides every "X pays Y" suggestion in the UI.
--
-- The trigger is DEFERRED so it only runs at transaction commit time. The
-- app inserts the expense first, then the participants — checking after
-- each row would reject the intermediate state.

create or replace function public.check_expense_shares_balance()
returns trigger language plpgsql as $$
declare
  affected_expense_id uuid;
  exp_amount numeric;
  shares_sum numeric;
  participant_count int;
begin
  affected_expense_id := coalesce(new.expense_id, old.expense_id);

  select e.amount into exp_amount
  from expenses e where e.id = affected_expense_id;

  if exp_amount is null then return new; end if;

  select coalesce(sum(ep.share_amount), 0), count(*)
  into shares_sum, participant_count
  from expense_participants ep
  where ep.expense_id = affected_expense_id;

  if participant_count > 0 and abs(shares_sum - exp_amount) > 0.01 then
    raise exception
      'expense_participants shares (%) must sum to expense amount (%) for expense %',
      shares_sum, exp_amount, affected_expense_id;
  end if;

  return new;
end $$;

drop trigger if exists trg_check_expense_shares_balance on public.expense_participants;
create constraint trigger trg_check_expense_shares_balance
  after insert or update or delete on public.expense_participants
  deferrable initially deferred
  for each row execute function public.check_expense_shares_balance();
