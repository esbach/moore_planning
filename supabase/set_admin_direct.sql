-- Direct script to set yourself as admin
-- Run this in Supabase SQL Editor

-- Step 1: Ensure your profile exists (create if it doesn't)
INSERT INTO public.profiles (id, email, full_name, is_admin)
SELECT 
  auth.uid(),
  (SELECT email FROM auth.users WHERE id = auth.uid()),
  COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = auth.uid()), 'Admin'),
  true
ON CONFLICT (id) 
DO UPDATE SET 
  is_admin = true,
  email = COALESCE(EXCLUDED.email, profiles.email);

-- Step 2: Verify it worked
SELECT 
  id,
  email,
  full_name,
  is_admin,
  CASE 
    WHEN is_admin = true THEN '✅ You are now an admin!'
    ELSE '❌ Something went wrong'
  END as status
FROM public.profiles
WHERE id = auth.uid();

-- Step 3: Test the admin check
SELECT 
  EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND COALESCE(is_admin, false) = true
  ) AS is_admin_check,
  'Should be TRUE now' AS note;

-- Step 4: Test project access
SELECT 
  id,
  name,
  description,
  created_at,
  'You should see this!' AS access_status
FROM public.projects;

