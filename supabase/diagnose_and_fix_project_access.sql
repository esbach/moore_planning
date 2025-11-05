-- Diagnose and fix project access issues
-- This will check all scenarios and fix what's needed

-- 1. Check if you're an admin
SELECT 
  id,
  email,
  is_admin,
  CASE 
    WHEN is_admin = true THEN '✅ You ARE an admin - you should see ALL projects'
    WHEN is_admin = false THEN '❌ You are NOT an admin'
    WHEN is_admin IS NULL THEN '⚠️ is_admin is NULL'
  END as admin_status
FROM public.profiles
WHERE id = auth.uid();

-- 2. Check what projects exist and who created them
SELECT 
  p.id,
  p.name,
  p.created_by,
  p.created_at,
  CASE 
    WHEN p.created_by = auth.uid() THEN '✅ You created this project'
    ELSE '❌ Created by someone else'
  END as ownership_status,
  -- Check if you're assigned via project_users
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM public.project_users pu 
      WHERE pu.project_id = p.id AND pu.user_id = auth.uid()
    ) THEN '✅ You are assigned via project_users'
    ELSE '❌ Not assigned via project_users'
  END as assignment_status
FROM public.projects p;

-- 3. Check your project_users assignments
SELECT 
  pu.*,
  p.name as project_name
FROM public.project_users pu
JOIN public.projects p ON p.id = pu.project_id
WHERE pu.user_id = auth.uid();

-- 4. OPTION A: Make yourself an admin (RECOMMENDED - easiest solution)
UPDATE public.profiles
SET is_admin = true
WHERE id = auth.uid();

-- 5. OPTION B: If you don't want to be a global admin, 
-- assign yourself to all existing projects instead
-- (Uncomment this if you prefer not to be a global admin)
/*
INSERT INTO public.project_users (project_id, user_id, role)
SELECT 
  p.id,
  auth.uid(),
  'admin'::text
FROM public.projects p
WHERE NOT EXISTS (
  SELECT 1 
  FROM public.project_users pu 
  WHERE pu.project_id = p.id 
  AND pu.user_id = auth.uid()
);
*/

-- 6. Verify you can now see projects
SELECT 
  id,
  name,
  description,
  created_at,
  'You can see this project!' as access_status
FROM public.projects;

-- 7. Final check - verify admin status
SELECT 
  EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND COALESCE(is_admin, false) = true
  ) AS is_admin_check,
  'If true, you should see all projects' AS note;

