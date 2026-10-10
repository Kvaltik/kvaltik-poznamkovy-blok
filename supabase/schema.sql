-- Kvaltík Notepad cloud synchronization.
-- Run once in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- This migration contains no credentials and does not delete user data.

create table if not exists public.notes (
    id uuid primary key,
    owner_id uuid not null references auth.users(id) on delete cascade,
    title text not null default 'Bez názvu',
    body text not null default '',
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists notes_owner_updated_idx
    on public.notes (owner_id, updated_at desc);

-- Mandatory: users may only read or change THEIR OWN rows.
alter table public.notes enable row level security;

drop policy if exists notes_select_own on public.notes;
create policy notes_select_own on public.notes
    for select to authenticated
    using ((select auth.uid()) = owner_id);

drop policy if exists notes_insert_own on public.notes;
create policy notes_insert_own on public.notes
    for insert to authenticated
    with check ((select auth.uid()) = owner_id);

drop policy if exists notes_update_own on public.notes;
create policy notes_update_own on public.notes
    for update to authenticated
    using ((select auth.uid()) = owner_id)
    with check ((select auth.uid()) = owner_id);

drop policy if exists notes_delete_own on public.notes;
create policy notes_delete_own on public.notes
    for delete to authenticated
    using ((select auth.uid()) = owner_id);

-- The database API uses the public publishable key together with user JWTs.
revoke all on table public.notes from anon;
grant select, insert, update, delete on table public.notes to authenticated;
