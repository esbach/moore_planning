-- Fix infinite recursion in project_users RLS policy
-- The issue is that the policy checks project_users while evaluating project_users itself
-- SOLUTION: Remove ALL cross-table checks from project_users policy to break the cycle

-- Drop the problematic policy
DROP POLICY IF EXISTS project_users_read_own_projects ON public.project_users;

-- Create a MUCH simpler policy WITHOUT any cross-table checks
-- Users can read project_users records if:
-- 1. They're the user being assigned (user_id = auth.uid())
-- 2. They're an admin
-- We DON'T check projects or project_users to avoid ANY possibility of recursion
CREATE POLICY project_users_read_own_projects ON public.project_users
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      -- User is assigned to this project (themselves) - direct check, no recursion
      user_id = auth.uid() OR
      -- User is admin (can see all assignments) - direct check, no recursion
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      )
    )
  );

-- Verify the policy is created
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'project_users'
ORDER BY policyname;

