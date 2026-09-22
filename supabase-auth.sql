-- ═══════════════════════════════════════════════════════════════════════════
-- SEVAK REGISTRY — require a login
--
-- This is what actually protects the data. Until now the policies said
-- "anyone may read and write", so the anon key sitting in index.html was
-- enough to open the whole registry. After this, that key opens nothing on
-- its own: every row needs a signed-in user, and Postgres enforces it, so it
-- holds even for someone reading the page source.
--
-- ─── DO THIS FIRST, IN THE DASHBOARD ───────────────────────────────────────
--
--  1. Authentication → Users → Add user → Create new user
--       Email:    the address you will sign in with
--       Password: the password you will sign in with
--       ✅ tick "Auto Confirm User"   ← without this, sign-in fails with
--                                        "Email not confirmed"
--
--  2. Authentication → Sign In / Providers → Email
--       ❌ turn OFF "Allow new users to sign up"
--
--     Leave this on and anyone who finds the site can create their own
--     account — and every policy below would then happily let them in.
--     This single switch is what keeps the login worth having.
--
-- ─── THEN RUN THIS FILE ────────────────────────────────────────────────────
--
-- Safe to run as many times as you like. It drops no table and rewrites no
-- row. If your registry table is not called `customers`, change the name in
-- the places marked  ◀── TABLE NAME.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
-- 1. THE REGISTRY — signed-in users only
-- ───────────────────────────────────────────────────────────────────────────

alter table public.customers enable row level security;          -- ◀── TABLE NAME

-- Every earlier policy has to go. Leaving one behind that allows `anon`
-- would defeat all of this: Postgres combines policies with OR, so the most
-- permissive one wins and the login becomes decoration.
drop policy if exists "anon read"         on public.customers;
drop policy if exists "anon write"        on public.customers;
drop policy if exists "public read"       on public.customers;
drop policy if exists "public write"      on public.customers;
drop policy if exists "sevak_all_access"  on public.customers;
drop policy if exists "sevak_authed"      on public.customers;

create policy "sevak_authed"
  on public.customers                                            -- ◀── TABLE NAME
  for all
  to authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on table public.customers to authenticated;
revoke all on table public.customers from anon;


-- ───────────────────────────────────────────────────────────────────────────
-- 2. STAFF LIST + ROTATION HISTORY — same rule
-- ───────────────────────────────────────────────────────────────────────────

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb,
  updated_at timestamptz default now()
);

alter table public.app_settings enable row level security;

drop policy if exists "anon read"           on public.app_settings;
drop policy if exists "anon write"          on public.app_settings;
drop policy if exists "settings_all_access" on public.app_settings;
drop policy if exists "settings_authed"     on public.app_settings;

create policy "settings_authed"
  on public.app_settings
  for all
  to authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on table public.app_settings to authenticated;
revoke all on table public.app_settings from anon;


-- ───────────────────────────────────────────────────────────────────────────
-- 3. REGISTRATION DATE — what the month and year-end views group by
--
--    Two statements on purpose. The one-liner
--        add column created_at timestamptz default now()
--    stamps today onto every existing row, so the whole back catalogue would
--    look like it was registered this morning.
-- ───────────────────────────────────────────────────────────────────────────

alter table public.customers add column if not exists created_at timestamptz;  -- ◀── TABLE NAME
alter table public.customers alter column created_at set default now();


-- ───────────────────────────────────────────────────────────────────────────
-- 4. SEQUENCES, so inserts can get their next id
-- ───────────────────────────────────────────────────────────────────────────

grant usage, select on all sequences in schema public to authenticated;
revoke all on all sequences in schema public from anon;


-- ───────────────────────────────────────────────────────────────────────────
-- 5. WAKE UP THE API — its schema cache goes stale after an `alter table`
-- ───────────────────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════
-- CHECKS — select one and press Run. They read the catalogue and change
-- nothing.
-- ═══════════════════════════════════════════════════════════════════════════

-- CHECK A — every policy should list `authenticated` and nothing should still
--           mention `anon`. A row naming anon is a way in without a password.
--
-- select c.relname as "table", p.polname as policy,
--        array(select rolname from pg_roles where oid = any(p.polroles)) as roles
--   from pg_policy p
--   join pg_class c on c.oid = p.polrelid
--   join pg_namespace n on n.oid = c.relnamespace
--  where n.nspname = 'public'
--    and c.relname in ('customers','app_settings')
--  order by 1, 2;

-- CHECK B — anon should have NO privileges left on either table.
--           An empty result is the correct answer.
--
-- select table_name, privilege_type
--   from information_schema.role_table_grants
--  where grantee = 'anon'
--    and table_schema = 'public'
--    and table_name in ('customers','app_settings');

-- CHECK C — your account should be listed, with a confirmation date.
--           A null confirmed_at means sign-in will fail.
--
-- select email, created_at, email_confirmed_at from auth.users order by created_at;
