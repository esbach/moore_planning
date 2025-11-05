-- Fix slow RLS policies by simplifying them
-- The issue is that checking through multiple JOINs is too slow
-- We'll create a simpler, faster approach using a helper function

-- Create a fast helper function to check if user has project access
CREATE OR REPLACE FUNCTION public.user_has_project_access(project_id_param uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  is_admin_check boolean;
  is_creator_check boolean;
  is_assigned_check boolean;
BEGIN
  -- Fast admin check (most common case for admins)
  SELECT COALESCE(is_admin, false) INTO is_admin_check
  FROM public.profiles
  WHERE id = auth.uid();
  
  IF is_admin_check THEN
    RETURN true;
  END IF;
  
  -- Fast creator check
  SELECT EXISTS(
    SELECT 1 FROM public.projects
    WHERE id = project_id_param AND created_by = auth.uid()
  ) INTO is_creator_check;
  
  IF is_creator_check THEN
    RETURN true;
  END IF;
  
  -- Fast assignment check
  SELECT EXISTS(
    SELECT 1 FROM public.project_users
    WHERE project_id = project_id_param AND user_id = auth.uid()
  ) INTO is_assigned_check;
  
  RETURN is_assigned_check;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.user_has_project_access(uuid) TO authenticated;

-- Now update outcomes policy (simplest one first)
DROP POLICY IF EXISTS outcomes_read_by_project_access ON public.outcomes;
DROP POLICY IF EXISTS outcomes_write_by_project_access ON public.outcomes;

CREATE POLICY outcomes_read_by_project_access ON public.outcomes
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      project_id IS NULL OR public.user_has_project_access(project_id)
    )
  );

CREATE POLICY outcomes_write_by_project_access ON public.outcomes
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      project_id IS NULL OR public.user_has_project_access(project_id)
    )
  );

-- Update objectives policy
DROP POLICY IF EXISTS objectives_read_by_project_access ON public.objectives;
DROP POLICY IF EXISTS objectives_write_by_project_access ON public.objectives;

CREATE POLICY objectives_read_by_project_access ON public.objectives
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 FROM public.outcomes o
        WHERE o.id = objectives.outcome_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id FROM public.outcomes o
        WHERE o.id = objectives.outcome_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

CREATE POLICY objectives_write_by_project_access ON public.objectives
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 FROM public.outcomes o
        WHERE o.id = objectives.outcome_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id FROM public.outcomes o
        WHERE o.id = objectives.outcome_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

-- Update outputs policy
DROP POLICY IF EXISTS outputs_read_by_project_access ON public.outputs;
DROP POLICY IF EXISTS outputs_write_by_project_access ON public.outputs;

CREATE POLICY outputs_read_by_project_access ON public.outputs
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

CREATE POLICY outputs_write_by_project_access ON public.outputs
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.objectives obj
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE obj.id = outputs.objective_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

-- Update activities policy
DROP POLICY IF EXISTS activities_read_by_project_access ON public.activities;
DROP POLICY IF EXISTS activities_write_by_project_access ON public.activities;

CREATE POLICY activities_read_by_project_access ON public.activities
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

CREATE POLICY activities_write_by_project_access ON public.activities
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.outputs op
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE op.id = activities.output_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

-- Update progress_updates policy
DROP POLICY IF EXISTS progress_updates_read_by_project_access ON public.progress_updates;
DROP POLICY IF EXISTS progress_updates_write_by_project_access ON public.progress_updates;

CREATE POLICY progress_updates_read_by_project_access ON public.progress_updates
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

CREATE POLICY progress_updates_write_by_project_access ON public.progress_updates
  FOR ALL
  USING (
    auth.role() = 'authenticated' AND (
      NOT EXISTS (
        SELECT 1 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id AND o.project_id IS NOT NULL
      ) OR
      public.user_has_project_access((
        SELECT o.project_id 
        FROM public.activities act
        JOIN public.outputs op ON op.id = act.output_id
        JOIN public.objectives obj ON obj.id = op.objective_id
        JOIN public.outcomes o ON o.id = obj.outcome_id
        WHERE act.id = progress_updates.activity_id AND o.project_id IS NOT NULL
        LIMIT 1
      ))
    )
  );

-- Test the helper function
SELECT public.user_has_project_access('00000000-0000-0000-0000-000000000000'::uuid) as test_result;

