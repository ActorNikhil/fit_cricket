-- ============================================================================
-- Fit Cricket — Supabase schema
-- ----------------------------------------------------------------------------
-- Run this once in the Supabase Dashboard → SQL Editor → New query.
-- It creates the tables that mirror the app's local SwiftData models, enables
-- Row-Level Security so each signed-in user only ever sees their own rows,
-- sets up an avatars storage bucket for profile photos, and turns on Realtime
-- so changes made on one device show up on the user's other devices.
--
-- Sync contract (client side, see SyncEngine.swift):
--   * every row carries `user_id` (= auth.uid()), `updated_at`, and — where the
--     app can delete — an `is_deleted` tombstone flag.
--   * conflicts resolve last-write-wins by `updated_at`.
--
-- Safe to re-run.
-- ============================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- ============================================================================
-- profiles — one row per auth user (the app is single-user per account)
-- ============================================================================
create table if not exists public.profiles (
    id          uuid        primary key references auth.users(id) on delete cascade,
    first_name  text        not null default '',
    last_name   text        not null default '',
    phone       text        not null default '',
    email       text        not null default '',
    role        text        not null default 'BAT',   -- PlayerRole rawValue (BAT/BOW/AR/WK)
    photo_path  text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

-- Backfill for databases created before `role` existed.
alter table public.profiles add column if not exists role text not null default 'BAT';

alter table public.profiles enable row level security;

-- Any signed-in user can look up players (read-only) so teams can be built from
-- the directory of registered members. Creating/updating/deleting stays owner-only.
drop policy if exists "profiles_owner_all" on public.profiles;
drop policy if exists "profiles_read_all_authenticated" on public.profiles;
create policy "profiles_read_all_authenticated" on public.profiles
    for select to authenticated using (true);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
    for insert to authenticated with check (auth.uid() = id);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
    for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own" on public.profiles
    for delete to authenticated using (auth.uid() = id);

-- Auto-create a profile row whenever a new auth user is created, so the client
-- can always assume its profile exists after the first sign-in.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, coalesce(new.email, ''))
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ============================================================================
-- saved_teams / saved_players — the user's team library
-- ============================================================================
create table if not exists public.saved_teams (
    id         uuid        primary key default gen_random_uuid(),
    user_id    uuid        not null references auth.users(id) on delete cascade,
    name       text        not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    is_deleted boolean     not null default false
);

create table if not exists public.saved_players (
    id         uuid        primary key default gen_random_uuid(),
    user_id    uuid        not null references auth.users(id) on delete cascade,
    team_id    uuid        references public.saved_teams(id) on delete cascade,
    name       text        not null default '',
    role       text        not null default 'BAT',   -- PlayerRole rawValue
    sort_order integer     not null default 0,
    updated_at timestamptz not null default now(),
    is_deleted boolean     not null default false
);

-- ============================================================================
-- player_career_stats — all-time totals per player name (drives leaderboard).
-- One row per (user, player name); never deleted, only upserted.
-- ============================================================================
create table if not exists public.player_career_stats (
    id            uuid        primary key default gen_random_uuid(),
    user_id       uuid        not null references auth.users(id) on delete cascade,
    name          text        not null default '',
    role          text        not null default 'BAT',
    matches       integer     not null default 0,
    runs          integer     not null default 0,
    balls         integer     not null default 0,
    fours         integer     not null default 0,
    sixes         integer     not null default 0,
    wickets       integer     not null default 0,
    balls_bowled  integer     not null default 0,
    runs_conceded integer     not null default 0,
    high_score    integer     not null default 0,
    best_bowling  integer     not null default 0,
    updated_at    timestamptz not null default now(),
    unique (user_id, name)
);

-- ============================================================================
-- calorie_entries — dated per-player calorie burn (id = the local UUID)
-- ============================================================================
create table if not exists public.calorie_entries (
    id                uuid             primary key,
    user_id           uuid             not null references auth.users(id) on delete cascade,
    date              timestamptz      not null default now(),
    player_name       text             not null default '',
    batting_calories  double precision not null default 0,
    bowling_calories  double precision not null default 0,
    fielding_calories double precision not null default 0,
    updated_at        timestamptz      not null default now(),
    is_deleted        boolean          not null default false
);

-- ============================================================================
-- completed_matches — durable record of finished matches (History tab)
-- ============================================================================
create table if not exists public.completed_matches (
    id                  uuid        primary key default gen_random_uuid(),
    user_id             uuid        not null references auth.users(id) on delete cascade,
    date                timestamptz not null default now(),
    first_batting_team  text        not null default '',
    first_runs          integer     not null default 0,
    first_wickets       integer     not null default 0,
    first_overs         text        not null default '',
    second_batting_team text        not null default '',
    second_runs         integer     not null default 0,
    second_wickets      integer     not null default 0,
    second_overs        text        not null default '',
    winner_name         text        not null default '',
    result_text         text        not null default '',
    total_overs         integer     not null default 0,
    man_of_the_match    text        not null default '',
    is_tie              boolean     not null default false,
    updated_at          timestamptz not null default now(),
    is_deleted          boolean     not null default false
);

-- ============================================================================
-- registered_players — self-registered player profiles (id = the local UUID)
-- ============================================================================
create table if not exists public.registered_players (
    id         uuid        primary key,
    user_id    uuid        not null references auth.users(id) on delete cascade,
    first_name text        not null default '',
    last_name  text        not null default '',
    phone      text        not null default '',
    email      text        not null default '',
    photo_path text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    is_deleted boolean     not null default false
);

-- ============================================================================
-- Row-Level Security — owner-only access on every user table
-- ============================================================================
do $$
declare t text;
begin
    foreach t in array array[
        'saved_teams', 'saved_players', 'player_career_stats',
        'calorie_entries', 'completed_matches', 'registered_players'
    ]
    loop
        execute format('alter table public.%I enable row level security;', t);
        execute format('drop policy if exists %I on public.%I;', t || '_owner_all', t);
        execute format(
            'create policy %I on public.%I for all using (auth.uid() = user_id) with check (auth.uid() = user_id);',
            t || '_owner_all', t
        );
    end loop;
end $$;

-- ============================================================================
-- Realtime — publish the user tables so other devices get live updates
-- ============================================================================
do $$
declare t text;
begin
    foreach t in array array[
        'profiles', 'saved_teams', 'saved_players', 'player_career_stats',
        'calorie_entries', 'completed_matches', 'registered_players'
    ]
    loop
        if not exists (
            select 1 from pg_publication_tables
            where pubname = 'supabase_realtime'
              and schemaname = 'public'
              and tablename = t
        ) then
            execute format('alter publication supabase_realtime add table public.%I;', t);
        end if;
    end loop;
end $$;

-- ============================================================================
-- Storage — private "avatars" bucket for profile / registered-player photos.
-- Files are keyed as "<user_id>/<filename>" so the folder = the owner.
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

drop policy if exists "avatars_owner_select" on storage.objects;
create policy "avatars_owner_select" on storage.objects
    for select using (
        bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "avatars_owner_insert" on storage.objects;
create policy "avatars_owner_insert" on storage.objects
    for insert with check (
        bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects
    for update using (
        bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects
    for delete using (
        bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
    );
