-- Debug script to check admin access issues
-- Run this to diagnose why admins can't see projects

-- 1. Check if your user profile exists and has is_admin set
select 
  id,
  email,
  full_name,
  is_admin,
  coalesce(is_admin, false) as is_admin_coalesced
from public.profiles
where id = auth.uid();

-- 2. Check if you're authenticated
select 
  auth.uid() as current_user_id,
  auth.role() as current_role;

-- 3. Check what projects exist
select 
  id,
  name,
  created_by,
  created_at
from public.projects;

-- 4. Check if you're assigned to any projects
select 
  pu.*,
  p.name as project_name
from public.project_users pu
join public.projects p on p.id = pu.project_id
where pu.user_id = auth.uid();

-- 5. Test the admin check directly
select 
  exists (
    select 1 
    from public.profiles 
    where id = auth.uid() 
    and coalesce(is_admin, false) = true
  ) as is_admin_check_passing;

-- 6. Check what policies exist on projects table
select 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public' and tablename = 'projects';

-- 7. Try to manually query projects (this should work if RLS is working)
-- This should return all projects if you're an admin
select * from public.projects;

