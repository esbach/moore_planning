-- Project Management SPA (Vue 3 + Supabase)
-- Schema and policies for MVP

-- Extensions (Supabase usually has these; keep for local clarity)
-- Uncomment if needed:
-- create extension if not exists pgcrypto;

-- Tables
create table if not exists public.outcomes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text
);

create table if not exists public.objectives (
  id uuid primary key default gen_random_uuid(),
  outcome_id uuid references public.outcomes(id) on delete cascade,
  title text not null,
  description text,
  index int
);

create table if not exists public.outputs (
  id uuid primary key default gen_random_uuid(),
  objective_id uuid references public.objectives(id) on delete cascade,
  title text not null,
  description text,
  index int
);

create table if not exists public.profiles (
  id uuid primary key,
  full_name text,
  email text
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  output_id uuid references public.outputs(id) on delete cascade,
  title text not null,
  description text,
  assignee_id uuid references public.profiles(id),
  start_date date,
  end_date date,
  progress int check (progress between 0 and 100) default 0,
  status text check (status in ('not_started','in_progress','blocked','done')) default 'not_started',
  source_links jsonb default '[]'::jsonb
);

alter table public.profiles
  add constraint profiles_auth_fk foreign key (id) references auth.users(id) on delete cascade;

create table if not exists public.progress_updates (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid references public.activities(id) on delete cascade,
  reported_by uuid references public.profiles(id),
  progress int check (progress between 0 and 100),
  status text check (status in ('not_started','in_progress','blocked','done')),
  notes text,
  created_at timestamp with time zone default now()
);

-- RLS
alter table public.outcomes enable row level security;
alter table public.objectives enable row level security;
alter table public.outputs enable row level security;
alter table public.profiles enable row level security;
alter table public.activities enable row level security;
alter table public.progress_updates enable row level security;

-- Simplified MVP policies: allow all authenticated users to read/write
do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'outcomes' and policyname = 'outcomes_read_all_authed'
  ) then
    create policy outcomes_read_all_authed on public.outcomes for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'outcomes' and policyname = 'outcomes_write_all_authed'
  ) then
    create policy outcomes_write_all_authed on public.outcomes for all using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'objectives' and policyname = 'objectives_read_all_authed'
  ) then
    create policy objectives_read_all_authed on public.objectives for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'objectives' and policyname = 'objectives_write_all_authed'
  ) then
    create policy objectives_write_all_authed on public.objectives for all using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'outputs' and policyname = 'outputs_read_all_authed'
  ) then
    create policy outputs_read_all_authed on public.outputs for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'outputs' and policyname = 'outputs_write_all_authed'
  ) then
    create policy outputs_write_all_authed on public.outputs for all using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_read_all_authed'
  ) then
    create policy profiles_read_all_authed on public.profiles for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_update_self'
  ) then
    create policy profiles_update_self on public.profiles for update using (auth.uid() = id);
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_insert_authed'
  ) then
    create policy profiles_insert_authed on public.profiles for insert with check (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'activities' and policyname = 'activities_read_all_authed'
  ) then
    create policy activities_read_all_authed on public.activities for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'activities' and policyname = 'activities_write_all_authed'
  ) then
    create policy activities_write_all_authed on public.activities for all using (auth.role() = 'authenticated');
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'progress_updates' and policyname = 'progress_updates_read_all_authed'
  ) then
    create policy progress_updates_read_all_authed on public.progress_updates for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'progress_updates' and policyname = 'progress_updates_write_all_authed'
  ) then
    create policy progress_updates_write_all_authed on public.progress_updates for all using (auth.role() = 'authenticated');
  end if;
end $$;

-- Optional: public storage bucket for links metadata (we store only URLs in DB)
-- Note: Supabase storage schema may vary; this is safe if storage is enabled
insert into storage.buckets (id, name, public)
values ('links', 'links', true)
on conflict (id) do nothing;
