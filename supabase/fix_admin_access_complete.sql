-- Complete fix for admin access issues
-- This script will:
-- 1. Ensure is_admin column exists on profiles
-- 2. Create/update your profile and set you as admin
-- 3. Fix RLS policies to work correctly

-- Step 1: Ensure is_admin column exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'profiles' 
      AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE public.profiles 
    ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;
    
    RAISE NOTICE 'Added is_admin column to profiles table';
  ELSE
    RAISE NOTICE 'is_admin column already exists';
  END IF;
END $$;

-- Step 2: Get your current user info
DO $$
DECLARE
  v_user_id uuid;
  v_user_email text;
BEGIN
  v_user_id := auth.uid();
  v_user_email := (SELECT email FROM auth.users WHERE id = v_user_id);
  
  RAISE NOTICE 'Your user ID: %', v_user_id;
  RAISE NOTICE 'Your email: %', v_user_email;
  
  -- Create or update your profile as admin
  INSERT INTO public.profiles (id, email, full_name, is_admin)
  VALUES (
    v_user_id,
    v_user_email,
    COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_user_id), 'Admin User'),
    true
  )
  ON CONFLICT (id) 
  DO UPDATE SET 
    is_admin = true,
    email = COALESCE(EXCLUDED.email, profiles.email),
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name);
  
  RAISE NOTICE 'Profile created/updated and set as admin';
END $$;

-- Step 3: Verify your profile
SELECT 
  id,
  email,
  full_name,
  is_admin,
  'Admin profile verified!' as status
FROM public.profiles
WHERE id = auth.uid();

-- Step 4: Fix the projects RLS policy to use COALESCE
DROP POLICY IF EXISTS projects_read_user_assigned ON public.projects;

CREATE POLICY projects_read_user_assigned ON public.projects
  FOR SELECT
  USING (
    auth.role() = 'authenticated' AND (
      -- User is admin (can see all projects) - using COALESCE to handle NULL
      EXISTS (
        SELECT 1 
        FROM public.profiles 
        WHERE id = auth.uid() 
        AND COALESCE(is_admin, false) = true
      ) OR
      -- User created the project
      created_by = auth.uid() OR
      -- User is assigned to the project
      EXISTS (
        SELECT 1 
        FROM public.project_users
        WHERE project_id = projects.id 
        AND user_id = auth.uid()
      )
    )
  );

-- Step 5: Test the admin check
SELECT 
  EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND COALESCE(is_admin, false) = true
  ) AS is_admin_check_passing,
  'Should be true if fix worked' AS note;

-- Step 6: Test project access (should return all projects if you're admin)
SELECT 
  id,
  name,
  description,
  created_by,
  created_at,
  'You can see this project!' AS access_status
FROM public.projects;

