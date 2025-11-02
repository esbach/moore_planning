-- Link existing outcomes, objectives, outputs, and activities to a project
-- This script will:
-- 1. Create a default project if none exists (or use existing)
-- 2. Link all outcomes without a project_id to that project

-- Step 1: Create a default project if it doesn't exist (optional - you can skip this if you already have a project)
-- Uncomment and modify the name/description as needed:
/*
INSERT INTO public.projects (id, name, description, created_by)
SELECT 
  gen_random_uuid(),
  'Atlas Amazon',
  'Default project for existing data',
  (SELECT id FROM public.profiles WHERE is_admin = true LIMIT 1)
WHERE NOT EXISTS (
  SELECT 1 FROM public.projects WHERE name = 'Atlas Amazon'
);
*/

-- Step 2: Update all outcomes without a project_id to link them to a project
-- Option A: Link to a specific project by name (uncomment and modify as needed):
/*
UPDATE public.outcomes
SET project_id = (SELECT id FROM public.projects WHERE name = 'Atlas Amazon' LIMIT 1)
WHERE project_id IS NULL;
*/

-- Option B: Link to a specific project by ID (replace 'YOUR-PROJECT-ID-HERE' with actual UUID):
/*
UPDATE public.outcomes
SET project_id = 'YOUR-PROJECT-ID-HERE'
WHERE project_id IS NULL;
*/

-- Option C: Link to the first available project (simpler, if you only have one project):
UPDATE public.outcomes
SET project_id = (SELECT id FROM public.projects ORDER BY created_at LIMIT 1)
WHERE project_id IS NULL;

-- Verify the update:
SELECT 
  o.id,
  o.title as outcome_title,
  o.project_id,
  p.name as project_name
FROM public.outcomes o
LEFT JOIN public.projects p ON o.project_id = p.id
ORDER BY o.title;


