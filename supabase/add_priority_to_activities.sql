-- Add priority field to activities table
alter table public.activities 
add column if not exists priority text check (priority in ('low', 'medium', 'high')) default 'medium';

-- Add comment for clarity
comment on column public.activities.priority is 'Priority level: low, medium, or high';

