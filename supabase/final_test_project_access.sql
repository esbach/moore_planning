-- Final test to verify everything is working
-- Run this and check if you see projects

-- 1. Verify you're an admin
SELECT 
  id,
  email,
  is_admin,
  '✅ You are an admin' as status
FROM public.profiles
WHERE id = auth.uid();

-- 2. Test the admin check that RLS uses
SELECT 
  (
    SELECT COALESCE(is_admin, false) 
    FROM public.profiles 
    WHERE id = auth.uid()
  ) = true AS admin_check_passing,
  'Should be TRUE' AS note;

-- 3. Direct query - should return all projects
SELECT 
  id,
  name,
  description,
  created_at,
  created_by
FROM public.projects
ORDER BY created_at DESC;

-- 4. Count projects you can see
SELECT 
  COUNT(*) as project_count,
  'projects you can access' as note
FROM public.projects;

