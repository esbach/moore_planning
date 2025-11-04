-- Add short_name field to outputs table
alter table public.outputs 
add column if not exists short_name text;

-- Add comment for clarity
comment on column public.outputs.short_name is 'Short name or code for the output (e.g., "A", "Alpha", "Out 1")';

