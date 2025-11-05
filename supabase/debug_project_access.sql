-- Debug script to check which projects a user can see and why
-- Run this in Supabase SQL editor to see what's happening

-- First, check your current user ID
SELECT 
  auth.uid() as current_user_id,
  (SELECT email FROM auth.users WHERE id = auth.uid()) as current_user_email;

-- Check if you're an admin
SELECT 
  id,
  email,
  is_admin,
  CASE 
    WHEN is_admin = true THEN 'You are a global admin (can see all projects)'
    ELSE 'You are NOT a global admin'
  END as admin_status
FROM public.profiles
WHERE id = auth.uid();

-- See all projects you're assigned to
SELECT 
  p.id,
  p.name,
  p.created_by,
  pu.role as your_role,
  'Assigned via project_users' as access_reason
FROM public.projects p
JOIN public.project_users pu ON pu.project_id = p.id
WHERE pu.user_id = auth.uid();

-- See all projects you created
SELECT 
  id,
  name,
  created_by,
  NULL as your_role,
  'Created by you' as access_reason
FROM public.projects
WHERE created_by = auth.uid()
AND id NOT IN (
  SELECT project_id FROM public.project_users WHERE user_id = auth.uid()
);

-- See ALL projects that should be visible to you (combining both above)
SELECT 
  p.id,
  p.name,
  p.created_by,
  COALESCE(pu.role, 'creator') as access_type,
  CASE 
    WHEN p.created_by = auth.uid() AND pu.user_id IS NULL THEN 'Created by you (not assigned)'
    WHEN pu.user_id IS NOT NULL THEN 'Assigned via project_users'
    WHEN p.created_by = auth.uid() THEN 'Created by you'
    ELSE 'Unknown access'
  END as access_reason
FROM public.projects p
LEFT JOIN public.project_users pu ON pu.project_id = p.id AND pu.user_id = auth.uid()
WHERE 
  p.created_by = auth.uid() OR
  pu.user_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
ORDER BY p.name;

-- If you see projects you shouldn't, check if they're actually in project_users
-- Replace 'PROJECT_ID_HERE' with the project ID you shouldn't see
-- SELECT 
--   pu.*,
--   p.name as project_name
-- FROM public.project_users pu
-- JOIN public.projects p ON p.id = pu.project_id
-- WHERE pu.project_id = 'PROJECT_ID_HERE' AND pu.user_id = auth.uid();

