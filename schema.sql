-- ===========================================================================
-- Ledgerly — Supabase schema.
-- Paste this whole file into your Supabase project: SQL Editor > New query >
-- Run. It is safe to run more than once.
--
-- TWO INDEPENDENT LAYERS KEEP USERS APART
--   1. Row Level Security below. Postgres itself refuses to return a row whose
--      user_id is not the signed-in user. This is enforced by the database, not
--      by application code, so a bug in the app cannot leak another user's rows.
--   2. End-to-end encryption in the client. Every row's contents are AES-256-GCM
--      ciphertext whose key never reaches this server. Even a full database dump
--      — by an attacker, by Supabase staff, by a subpoena — yields nothing
--      readable.
--
-- Layer 1 without layer 2 would mean Supabase can read your ledger.
-- Layer 2 without layer 1 would mean anyone could download everyone's blobs.
-- Together, neither a compromised server nor a compromised account alone is
-- enough to read a single transaction.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- records — every party and every transaction, encrypted.
-- The server deliberately knows nothing about what a row contains: not the
-- party name, not the amount, not the date, not even whether it is a party or
-- a transaction. All of that is inside `ciphertext`.
-- ---------------------------------------------------------------------------
create table if not exists public.records (
  id          text        not null,
  user_id     uuid        not null references auth.users (id) on delete cascade,
  ciphertext  text        not null,
  iv          text        not null,
  -- A tombstone, so a delete on one device propagates instead of the row
  -- simply reappearing on the next sync from another device.
  deleted     boolean     not null default false,
  updated_at  timestamptz not null default now(),
  primary key (user_id, id)
);

-- Sync asks "what changed since I last looked?" on every pass.
create index if not exists records_user_updated_idx
  on public.records (user_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- vaults — one row per user: the master key, wrapped with a key derived from
-- the passphrase. Storing it here is what lets you sign in on a new device and
-- recover your ledger with nothing but your login and your passphrase.
--
-- This row is NOT a way in. Without the passphrase it is an opaque blob, and
-- the passphrase is never sent here in any form, hashed or otherwise.
-- ---------------------------------------------------------------------------
create table if not exists public.vaults (
  user_id        uuid        primary key references auth.users (id) on delete cascade,
  wrapped_key    text        not null,
  salt           text        not null,
  iv             text        not null,
  kdf_iterations integer     not null default 310000,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security. Without these policies the tables are readable by any
-- authenticated user; with them, `auth.uid()` — taken from the signed JWT, not
-- from anything the client can claim — scopes every statement to its owner.
-- ---------------------------------------------------------------------------
alter table public.records enable row level security;
alter table public.vaults  enable row level security;

drop policy if exists "records are private to their owner" on public.records;
create policy "records are private to their owner"
  on public.records
  for all
  to authenticated
  using      (auth.uid() = user_id)   -- which rows you may read/update/delete
  with check (auth.uid() = user_id);  -- and what you may write as your own

drop policy if exists "vaults are private to their owner" on public.vaults;
create policy "vaults are private to their owner"
  on public.vaults
  for all
  to authenticated
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Anonymous visitors get nothing at all. (No policy for the `anon` role means
-- no access, which is what we want: the public anon key alone opens nothing.)

-- ---------------------------------------------------------------------------
-- Keep updated_at honest. The client sends its own value for conflict
-- resolution, but a trigger means a client cannot backdate a row to win a
-- conflict it should have lost, nor stall another device's sync cursor.
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists records_touch_updated_at on public.records;
create trigger records_touch_updated_at
  before insert or update on public.records
  for each row execute function public.touch_updated_at();

drop trigger if exists vaults_touch_updated_at on public.vaults;
create trigger vaults_touch_updated_at
  before insert or update on public.vaults
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Defence in depth: force user_id to the signed-in user on insert, so a
-- malformed or malicious client cannot even attempt to write into someone
-- else's account. The RLS check above would already reject it; this makes the
-- correct behaviour automatic rather than merely enforced.
-- ---------------------------------------------------------------------------
create or replace function public.force_owner()
returns trigger
language plpgsql
as $$
begin
  new.user_id := auth.uid();
  return new;
end;
$$;

drop trigger if exists records_force_owner on public.records;
create trigger records_force_owner
  before insert on public.records
  for each row execute function public.force_owner();

drop trigger if exists vaults_force_owner on public.vaults;
create trigger vaults_force_owner
  before insert on public.vaults
  for each row execute function public.force_owner();
