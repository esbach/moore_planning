-- Fix all RLS policies to prevent infinite recursion
-- The issue is that policies are checking each other in a circular way

-- First, let's simplify project_users policy to avoid ANY cross-table checks that could cause recursion
DROP POLICY IF EXISTS project_users_read_own_projects ON public.project_users;

CREATE POLICY project_users_read_own_projects ON public.project_users
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      -- User is assigned (themselves)
      user_id = auth.uid() OR
      -- User is admin (direct check, no recursion)
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      )
    )
  );

-- Now fix projects policy - make sure it doesn't cause recursion when project_users is queried
DROP POLICY IF EXISTS projects_read_user_assigned ON public.projects;

CREATE POLICY projects_read_user_assigned ON public.projects
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      -- Admin check (direct, no recursion)
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      -- User created the project (direct, no recursion)
      created_by = auth.uid() OR
      -- User is assigned - this is the only place we check project_users for projects
      EXISTS (
        SELECT 1 
        FROM public.project_users
        WHERE project_id = projects.id 
        AND user_id = auth.uid()
      )
    )
  );

-- Fix outcomes policy - make sure it doesn't cause recursion
DROP POLICY IF EXISTS outcomes_read_by_project_access ON public.outcomes;
DROP POLICY IF EXISTS outcomes_write_by_project_access ON public.outcomes;

CREATE POLICY outcomes_read_by_project_access ON public.outcomes
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      -- Admin can see all
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      -- Legacy data without project
      project_id IS NULL OR
      -- Check project access WITHOUT checking project_users recursively
      -- Instead, check if user is admin, creator, or directly assigned
      EXISTS (
        SELECT 1 
        FROM public.projects p
        WHERE p.id = outcomes.project_id
        AND (
          p.created_by = auth.uid() OR
          EXISTS (
            SELECT 1 
            FROM public.profiles 
            WHERE id = auth.uid() 
            AND COALESCE(is_admin, false) = true
          ) OR
          EXISTS (
            SELECT 1 
            FROM public.project_users pu
            WHERE pu.project_id = p.id 
            AND pu.user_id = auth.uid()
          )
        )
      )
    )
  );

CREATE POLICY outcomes_write_by_project_access ON public.outcomes
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      project_id IS NULL OR
      EXISTS (
        SELECT 1 
        FROM public.projects p
        WHERE p.id = outcomes.project_id
        AND (
          p.created_by = auth.uid() OR
          EXISTS (
            SELECT 1 
            FROM public.profiles 
            WHERE id = auth.uid() 
            AND COALESCE(is_admin, false) = true
          ) OR
          EXISTS (
            SELECT 1 
            FROM public.project_users pu
            WHERE pu.project_id = p.id 
            AND pu.user_id = auth.uid()
          )
        )
      )
    )
  );

-- Test that policies are working
SELECT 
  policyname,
  tablename
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename IN ('projects', 'project_users', 'outcomes')
ORDER BY tablename, policyname;

