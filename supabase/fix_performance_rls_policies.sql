-- Fix performance issues in RLS policies
-- The policies are too complex with deep nested queries causing timeouts
-- We'll simplify them significantly

-- First, create a helper function to check project access (much faster than nested queries)
CREATE OR REPLACE FUNCTION public.user_has_project_access(project_id_param uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND COALESCE(is_admin, false) = true
  ) OR EXISTS (
    SELECT 1 
    FROM public.projects p
    WHERE p.id = project_id_param
    AND p.created_by = auth.uid()
  ) OR EXISTS (
    SELECT 1 
    FROM public.project_users pu
    WHERE pu.project_id = project_id_param
    AND pu.user_id = auth.uid()
  );
$$;

-- Now simplify all policies using this function

-- Activities policy (simplified - check project via output -> objective -> outcome)
DROP POLICY IF EXISTS activities_read_by_project_access ON public.activities;
DROP POLICY IF EXISTS activities_write_by_project_access ON public.activities;

CREATE POLICY activities_read_by_project_access ON public.activities
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
      -- Legacy data without project (no project_id in outcome)
      NOT EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id
        AND o.project_id IS NOT NULL
      ) OR
      -- Check project access using the helper function
      EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

CREATE POLICY activities_write_by_project_access ON public.activities
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

-- Outputs policy (simplified)
DROP POLICY IF EXISTS outputs_read_by_project_access ON public.outputs;
DROP POLICY IF EXISTS outputs_write_by_project_access ON public.outputs;

CREATE POLICY outputs_read_by_project_access ON public.outputs
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

CREATE POLICY outputs_write_by_project_access ON public.outputs
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

-- Objectives policy (simplified)
DROP POLICY IF EXISTS objectives_read_by_project_access ON public.objectives;
DROP POLICY IF EXISTS objectives_write_by_project_access ON public.objectives;

CREATE POLICY objectives_read_by_project_access ON public.objectives
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.outcomes o
        WHERE o.id = objectives.outcome_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.outcomes o
        WHERE o.id = objectives.outcome_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

CREATE POLICY objectives_write_by_project_access ON public.objectives
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.outcomes o
        WHERE o.id = objectives.outcome_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.outcomes o
        WHERE o.id = objectives.outcome_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

-- Outcomes policy (simplified)
DROP POLICY IF EXISTS outcomes_read_by_project_access ON public.outcomes;
DROP POLICY IF EXISTS outcomes_write_by_project_access ON public.outcomes;

CREATE POLICY outcomes_read_by_project_access ON public.outcomes
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      project_id IS NULL OR
      public.user_has_project_access(project_id)
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
      public.user_has_project_access(project_id)
    )
  );

-- Progress updates policy (simplified)
DROP POLICY IF EXISTS progress_updates_read_by_project_access ON public.progress_updates;
DROP POLICY IF EXISTS progress_updates_write_by_project_access ON public.progress_updates;

CREATE POLICY progress_updates_read_by_project_access ON public.progress_updates
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

CREATE POLICY progress_updates_write_by_project_access ON public.progress_updates
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      NOT EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id
        AND o.project_id IS NOT NULL
      ) OR
      EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id
        AND o.project_id IS NOT NULL
        AND public.user_has_project_access(o.project_id)
      )
    )
  );

-- Verify policies are created
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename IN ('activities', 'outputs', 'objectives', 'outcomes', 'progress_updates', 'projects')
ORDER BY tablename, policyname;

