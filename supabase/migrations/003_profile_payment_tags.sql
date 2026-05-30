-- Public payment handles users can advertise so others can pay them.
-- revolut_tag is the user's revolut.me username (used in deep links).
-- bizum_phone is shown as copy-able text only — Bizum has no public deep link.
alter table public.profiles
  add column if not exists revolut_tag text,
  add column if not exists bizum_phone text;

comment on column public.profiles.revolut_tag is
  'User''s revolut.me handle (without @). Used to build deep-link payment URLs.';
comment on column public.profiles.bizum_phone is
  'User''s Bizum phone number in E.164 (e.g. +34600000000). Displayed for copy/paste only — Bizum has no public deep link.';
