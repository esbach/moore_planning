-- Add projects table and update outcomes to reference projects

-- Create projects table
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamp with time zone default now(),
  created_by uuid references public.profiles(id)
);

-- Add project_id to outcomes (nullable for now to handle existing data)
alter table public.outcomes
  add column if not exists project_id uuid references public.projects(id) on delete cascade;

-- Enable RLS for projects
alter table public.projects enable row level security;

-- Policies for projects: all authenticated users can read, only admins can write
do $$ begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'projects' and policyname = 'projects_read_all_authed'
  ) then
    create policy projects_read_all_authed on public.projects for select using (auth.role() = 'authenticated');
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'projects' and policyname = 'projects_insert_admin_only'
  ) then
    create policy projects_insert_admin_only on public.projects for insert 
      with check (
        auth.role() = 'authenticated' 
        and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
      );
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'projects' and policyname = 'projects_update_admin_only'
  ) then
    create policy projects_update_admin_only on public.projects for update 
      using (
        auth.role() = 'authenticated' 
        and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
      );
  end if;
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'projects' and policyname = 'projects_delete_admin_only'
  ) then
    create policy projects_delete_admin_only on public.projects for delete 
      using (
        auth.role() = 'authenticated' 
        and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
      );
  end if;
end $$;

-- Add comment for clarity
comment on table public.projects is 'Top-level projects that contain outcomes';
comment on column public.outcomes.project_id is 'The project this outcome belongs to';

