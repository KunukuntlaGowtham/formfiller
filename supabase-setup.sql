-- ═══════════════════════════════════════════════════════════════════════════
-- SEVAK REGISTRY — Supabase setup / repair
--
-- Run this whole file in the Supabase SQL editor (Run ▶).
-- It is SAFE TO RUN AS MANY TIMES AS YOU LIKE:
--   • it never drops a table
--   • it never deletes or rewrites a single row
--   • it only adds what is missing and re-grants access
--
-- If your registry table is not called `customers`, change the name in the
-- three places marked  ◀── TABLE NAME  and run it again.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
-- 1. THE REGISTRY TABLE — make it readable and writable by the app again
--
--    This is the part that was broken. When Row Level Security is ON but a
--    table has no policy, Postgres does not throw an error — it simply
--    returns ZERO ROWS. From JavaScript that looks exactly like "the data
--    vanished": no error in the console, just an empty list.
-- ───────────────────────────────────────────────────────────────────────────

alter table public.customers enable row level security;   -- ◀── TABLE NAME

drop policy if exists "anon read"        on public.customers;
drop policy if exists "anon write"       on public.customers;
drop policy if exists "public read"      on public.customers;
drop policy if exists "public write"     on public.customers;
drop policy if exists "sevak_all_access" on public.customers;

create policy "sevak_all_access"
  on public.customers                                     -- ◀── TABLE NAME
  for all
  to anon, authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on table public.customers to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────────
-- 2. STAFF LIST + ROTATION HISTORY  (the ☁ SYNCED badge on the STAFF tab)
-- ───────────────────────────────────────────────────────────────────────────

create table if not exists public.app_settings (
  key        text primary key,
  value      jsonb,
  updated_at timestamptz default now()
);

alter table public.app_settings enable row level security;

drop policy if exists "anon read"          on public.app_settings;
drop policy if exists "anon write"         on public.app_settings;
drop policy if exists "settings_all_access" on public.app_settings;

create policy "settings_all_access"
  on public.app_settings
  for all
  to anon, authenticated
  using (true)
  with check (true);

grant select, insert, update, delete on table public.app_settings to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────────
-- 3. REGISTRATION DATE — what the month view and year-end report group by
--
--    Deliberately two statements. The one-liner
--        add column created_at timestamptz default now()
--    stamps TODAY onto every existing row, so your whole back catalogue would
--    look like it was registered this morning. Split like this, old rows stay
--    NULL (honestly "date unknown") and only new registrations get stamped.
-- ───────────────────────────────────────────────────────────────────────────

alter table public.customers add column if not exists created_at timestamptz;   -- ◀── TABLE NAME
alter table public.customers alter column created_at set default now();


-- ───────────────────────────────────────────────────────────────────────────
-- 4. SEQUENCES — so inserts can get their next id
-- ───────────────────────────────────────────────────────────────────────────

grant usage, select on all sequences in schema public to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────────
-- 5. WAKE UP THE API
--
--    Supabase's API layer keeps a cached copy of your schema. After an
--    `alter table` that cache can go stale, and the API then answers about a
--    table shape that no longer matches reality — another way data goes
--    "missing" with no error. This line forces a reload.
-- ───────────────────────────────────────────────────────────────────────────

notify pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════
-- DONE. Now run the two checks below (select them and press Run) —
-- they read nothing but the catalogue and change nothing.
-- ═══════════════════════════════════════════════════════════════════════════

-- CHECK A — every table the app touches should show at least one policy.
--           A row with policy = NULL is a table the app cannot read.
--
-- select c.relname          as table,
--        c.relrowsecurity   as rls_on,
--        p.polname          as policy
--   from pg_class c
--   join pg_namespace n on n.oid = c.relnamespace
--   left join pg_policy p on p.polrelid = c.oid
--  where n.nspname = 'public'
--    and c.relname in ('customers','app_settings')
--  order by 1, 3;

-- CHECK B — how many rows the app will actually see.
--           If this number is right but the app still shows nothing,
--           the problem is in the browser, not in the database.
--
-- select count(*) as rows_visible from public.customers;
