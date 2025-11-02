-- Add is_admin column to profiles table
alter table public.profiles
  add column if not exists is_admin boolean default false not null;

-- Add comment for clarity
comment on column public.profiles.is_admin is 'Whether this user has admin privileges';



