-- Add progress_updates table for tracking progress update history

-- Create the table
create table if not exists public.progress_updates (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid references public.activities(id) on delete cascade,
  reported_by uuid references public.profiles(id),
  progress int check (progress between 0 and 100),
  status text check (status in ('not_started','in_progress','blocked','done')),
  notes text,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.progress_updates enable row level security;

-- Add policies
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

