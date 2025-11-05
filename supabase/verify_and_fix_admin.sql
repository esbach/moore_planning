-- Quick script to verify and fix your admin status
-- Run this while logged in to Supabase SQL Editor

-- 1. Check your current profile status
SELECT 
  id,
  email,
  full_name,
  is_admin,
  CASE 
    WHEN is_admin = true THEN '✅ You ARE an admin'
    WHEN is_admin = false THEN '❌ You are NOT an admin'
    WHEN is_admin IS NULL THEN '⚠️ is_admin is NULL (problem!)'
  END as admin_status
FROM public.profiles
WHERE id = auth.uid();

-- 2. If you're not an admin, set yourself as admin
UPDATE public.profiles
SET is_admin = true
WHERE id = auth.uid();

-- 3. Verify the update worked
SELECT 
  id,
  email,
  full_name,
  is_admin,
  '✅ You are now set as admin!' as status
FROM public.profiles
WHERE id = auth.uid();

-- 4. Test if the admin check works in RLS context
SELECT 
  EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND COALESCE(is_admin, false) = true
  ) AS admin_check_passing,
  'Should return true' AS note;

-- 5. Test project access - should see all projects if admin check passes
SELECT 
  id,
  name,
  description,
  created_at,
  created_by
FROM public.projects;

