-- Fix project RLS policies to ensure admins can see all projects
-- This script fixes the issue where admins can't see projects after the migration

-- First, let's check what policies exist and drop/recreate the problematic one
drop policy if exists projects_read_user_assigned on public.projects;

-- Create a more robust policy that ensures admins can always see projects
-- The issue might be that the profile lookup is failing or is_admin is not set correctly
create policy projects_read_user_assigned on public.projects
  for select
  using (
    auth.role() = 'authenticated' and (
      -- User is admin (can see all projects) - check if profile exists and is_admin is true
      -- Using COALESCE to handle NULL is_admin values as false
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
      -- User created the project
      created_by = auth.uid() or
      -- User is assigned to the project
      exists (
        select 1 
        from public.project_users
        where project_id = projects.id 
        and user_id = auth.uid()
      )
    )
  );

-- Also update the other policies to use the same robust admin check
-- Update outcomes policy
drop policy if exists outcomes_read_by_project_access on public.outcomes;
create policy outcomes_read_by_project_access on public.outcomes
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Update outcomes write policy
drop policy if exists outcomes_write_by_project_access on public.outcomes;
create policy outcomes_write_by_project_access on public.outcomes
  for all
  using (
    auth.role() = 'authenticated' and (
      -- Admin can write all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Similar updates for objectives, outputs, activities, and progress_updates
-- Update objectives
drop policy if exists objectives_read_by_project_access on public.objectives;
drop policy if exists objectives_write_by_project_access on public.objectives;

create policy objectives_read_by_project_access on public.objectives
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
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
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Update outputs
drop policy if exists outputs_read_by_project_access on public.outputs;
drop policy if exists outputs_write_by_project_access on public.outputs;

create policy outputs_read_by_project_access on public.outputs
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
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
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Update activities
drop policy if exists activities_read_by_project_access on public.activities;
drop policy if exists activities_write_by_project_access on public.activities;

create policy activities_read_by_project_access on public.activities
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
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
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Update progress_updates
drop policy if exists progress_updates_read_by_project_access on public.progress_updates;
drop policy if exists progress_updates_write_by_project_access on public.progress_updates;

create policy progress_updates_read_by_project_access on public.progress_updates
  for select
  using (
    auth.role() = 'authenticated' and (
      -- Admin can see all
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
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
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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
          ) or
          exists (
            select 1 
            from public.profiles 
            where id = auth.uid() 
            and coalesce(is_admin, false) = true
          )
        )
      )
    )
  );

-- Update project_users policies to use the same robust admin check
drop policy if exists project_users_read_own_projects on public.project_users;
drop policy if exists project_users_insert_admin_only on public.project_users;
drop policy if exists project_users_update_admin_only on public.project_users;
drop policy if exists project_users_delete_admin_only on public.project_users;

create policy project_users_read_own_projects on public.project_users
  for select
  using (
    auth.role() = 'authenticated' and (
      -- User is assigned to this project
      user_id = auth.uid() or
      -- User is admin (can see all assignments)
      exists (
        select 1 
        from public.profiles 
        where id = auth.uid() 
        and coalesce(is_admin, false) = true
      ) or
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

create policy project_users_insert_admin_only on public.project_users
  for insert
  with check (
    auth.role() = 'authenticated'
    and exists (
      select 1 
      from public.profiles 
      where id = auth.uid() 
      and coalesce(is_admin, false) = true
    )
  );

create policy project_users_update_admin_only on public.project_users
  for update
  using (
    auth.role() = 'authenticated'
    and exists (
      select 1 
      from public.profiles 
      where id = auth.uid() 
      and coalesce(is_admin, false) = true
    )
  );

create policy project_users_delete_admin_only on public.project_users
  for delete
  using (
    auth.role() = 'authenticated'
    and exists (
      select 1 
      from public.profiles 
      where id = auth.uid() 
      and coalesce(is_admin, false) = true
    )
  );

