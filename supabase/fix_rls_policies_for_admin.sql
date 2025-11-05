-- Fix RLS policies to ensure admins can see projects
-- Since you're already an admin, the issue is with the policies

-- Step 1: Check current policies on projects table
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'projects'
ORDER BY policyname;

-- Step 2: Drop the existing read policy (if it exists)
DROP POLICY IF EXISTS projects_read_user_assigned ON public.projects;
DROP POLICY IF EXISTS projects_read_all_authed ON public.projects;

-- Step 3: Create a new, simpler policy that definitely works for admins
CREATE POLICY projects_read_user_assigned ON public.projects
  FOR SELECT
  USING (
    -- Must be authenticated
    auth.role() = 'authenticated' AND (
      -- Check if user is admin (with explicit boolean check)
      (
        SELECT COALESCE(is_admin, false) 
        FROM public.profiles 
        WHERE id = auth.uid()
      ) = true
      OR
      -- User created the project
      created_by = auth.uid()
      OR
      -- User is assigned to the project
      EXISTS (
        SELECT 1 
        FROM public.project_users
        WHERE project_id = projects.id 
        AND user_id = auth.uid()
      )
    )
  );

-- Step 4: Test the admin check directly
SELECT 
  (SELECT COALESCE(is_admin, false) FROM public.profiles WHERE id = auth.uid()) as is_admin_value,
  auth.uid() as your_user_id,
  'Should show true' as note;

-- Step 5: Test project access - should work now
SELECT 
  id,
  name,
  description,
  created_at,
  'You should see this!' AS access_status
FROM public.projects;

-- Step 6: Verify the policy is working
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM public.projects;

