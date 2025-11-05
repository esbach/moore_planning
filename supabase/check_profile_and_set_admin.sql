-- Check your profile and set admin status if needed
-- Run this in Supabase SQL Editor while logged in

-- 1. First, check if your profile exists and what columns it has
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check your current profile data
SELECT 
  id,
  email,
  full_name,
  is_admin
FROM public.profiles
WHERE id = auth.uid();

-- 3. Check if is_admin column exists (if the above doesn't show it)
-- If the column doesn't exist, we need to add it
DO $$ 
BEGIN
  -- Check if is_admin column exists, if not add it
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

-- 4. Set yourself as admin (replace with your user ID if needed)
-- First, let's see what your user ID is:
SELECT 
  auth.uid() as your_user_id,
  (SELECT email FROM auth.users WHERE id = auth.uid()) as your_email;

-- 5. Update your profile to be admin
-- This will create your profile if it doesn't exist, or update it if it does
INSERT INTO public.profiles (id, email, full_name, is_admin)
SELECT 
  auth.uid(),
  (SELECT email FROM auth.users WHERE id = auth.uid()),
  COALESCE((SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = auth.uid()), 'Admin User'),
  true
ON CONFLICT (id) 
DO UPDATE SET 
  is_admin = true,
  email = COALESCE(EXCLUDED.email, profiles.email),
  full_name = COALESCE(EXCLUDED.full_name, profiles.full_name);

-- 6. Verify you're now an admin
SELECT 
  id,
  email,
  full_name,
  is_admin,
  'You are now an admin!' as status
FROM public.profiles
WHERE id = auth.uid();

