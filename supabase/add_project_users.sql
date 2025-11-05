-- Add project_users junction table for linking users to projects
-- This allows users to see only projects they're assigned to (unless they're admins)

-- Create project_users junction table
create table if not exists public.project_users (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text check (role in ('viewer', 'editor', 'admin')) default 'viewer',
  created_at timestamp with time zone default now(),
  unique(project_id, user_id)
);

-- Enable RLS for project_users
alter table public.project_users enable row level security;

-- Users can read project_users records for projects they have access to
-- (This will be checked via the project access policies)
create policy project_users_read_own_projects on public.project_users
  for select
  using (
    auth.role() = 'authenticated' and (
      -- User is assigned to this project
      user_id = auth.uid() or
      -- User is admin (can see all assignments)
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- User can access the project (via project_users or as creator)
      exists (
        select 1 from public.projects p
        where p.id = project_users.project_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Only admins can manage project-user assignments
create policy project_users_insert_admin_only on public.project_users
  for insert
  with check (
    auth.role() = 'authenticated'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

create policy project_users_update_admin_only on public.project_users
  for update
  using (
    auth.role() = 'authenticated'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

create policy project_users_delete_admin_only on public.project_users
  for delete
  using (
    auth.role() = 'authenticated'
    and exists (select 1 from public.profiles where id = auth.uid() and is_admin = true)
  );

-- Update projects RLS policies to check project_users
-- Drop old policies first
drop policy if exists projects_read_all_authed on public.projects;

-- New policy: users can only see projects they're assigned to or created, or if they're admins
create policy projects_read_user_assigned on public.projects
  for select
  using (
    auth.role() = 'authenticated' and (
      -- User is admin (can see all projects)
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- User created the project
      created_by = auth.uid() or
      -- User is assigned to the project
      exists (
        select 1 from public.project_users
        where project_id = projects.id and user_id = auth.uid()
      )
    )
  );

-- Update outcomes RLS to respect project access
drop policy if exists outcomes_read_all_authed on public.outcomes;
drop policy if exists outcomes_write_all_authed on public.outcomes;

-- Outcomes: users can read if they have access to the parent project
create policy outcomes_read_by_project_access on public.outcomes
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Outcome has no project (legacy data) - allow access for now
      project_id is null or
      -- User has access to the project
      exists (
        select 1 from public.projects p
        where p.id = outcomes.project_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Outcomes: users can write if they have access to the parent project
create policy outcomes_write_by_project_access on public.outcomes
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Outcome has no project (legacy data) - allow access for now
      project_id is null or
      -- User has access to the project
      exists (
        select 1 from public.projects p
        where p.id = outcomes.project_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Update objectives RLS to respect project access (via outcomes)
drop policy if exists objectives_read_all_authed on public.objectives;
drop policy if exists objectives_write_all_authed on public.objectives;

create policy objectives_read_by_project_access on public.objectives
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.outcomes o
        where o.id = objectives.outcome_id and o.project_id is not null
      ) or
      -- User has access to the project via the outcome
      exists (
        select 1 from public.outcomes o
        join public.projects p on p.id = o.project_id
        where o.id = objectives.outcome_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

create policy objectives_write_by_project_access on public.objectives
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.outcomes o
        where o.id = objectives.outcome_id and o.project_id is not null
      ) or
      -- User has access to the project via the outcome
      exists (
        select 1 from public.outcomes o
        join public.projects p on p.id = o.project_id
        where o.id = objectives.outcome_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Update outputs RLS to respect project access (via objectives -> outcomes)
drop policy if exists outputs_read_all_authed on public.outputs;
drop policy if exists outputs_write_all_authed on public.outputs;

create policy outputs_read_by_project_access on public.outputs
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.objectives obj
        join public.outcomes o on o.id = obj.outcome_id
        where obj.id = outputs.objective_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.objectives obj
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where obj.id = outputs.objective_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

create policy outputs_write_by_project_access on public.outputs
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.objectives obj
        join public.outcomes o on o.id = obj.outcome_id
        where obj.id = outputs.objective_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.objectives obj
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where obj.id = outputs.objective_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Update activities RLS to respect project access (via outputs -> objectives -> outcomes)
drop policy if exists activities_read_all_authed on public.activities;
drop policy if exists activities_write_all_authed on public.activities;

create policy activities_read_by_project_access on public.activities
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Activity's output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.outputs op
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        where op.id = activities.output_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.outputs op
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where op.id = activities.output_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

create policy activities_write_by_project_access on public.activities
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Activity's output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.outputs op
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        where op.id = activities.output_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.outputs op
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where op.id = activities.output_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Update progress_updates RLS to respect project access (via activities)
drop policy if exists progress_updates_read_all_authed on public.progress_updates;
drop policy if exists progress_updates_write_all_authed on public.progress_updates;

create policy progress_updates_read_by_project_access on public.progress_updates
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Progress update's activity's output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.activities act
        join public.outputs op on op.id = act.output_id
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        where act.id = progress_updates.activity_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.activities act
        join public.outputs op on op.id = act.output_id
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where act.id = progress_updates.activity_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

create policy progress_updates_write_by_project_access on public.progress_updates
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) or
      -- Progress update's activity's output's objective's outcome has no project (legacy data) - allow access
      not exists (
        select 1 from public.activities act
        join public.outputs op on op.id = act.output_id
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        where act.id = progress_updates.activity_id and o.project_id is not null
      ) or
      -- User has access to the project via the hierarchy
      exists (
        select 1 from public.activities act
        join public.outputs op on op.id = act.output_id
        join public.objectives obj on obj.id = op.objective_id
        join public.outcomes o on o.id = obj.outcome_id
        join public.projects p on p.id = o.project_id
        where act.id = progress_updates.activity_id
        and (
          p.created_by = auth.uid() or
          exists (
            select 1 from public.project_users pu
            where pu.project_id = p.id and pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Add comments
comment on table public.project_users is 'Junction table linking users to projects with role-based access';
comment on column public.project_users.role is 'User role within the project: viewer (read-only), editor (read/write), admin (full control)';

