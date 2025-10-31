-- Add short_name field to objectives table
alter table public.objectives 
add column if not exists short_name text;

-- Add comment for clarity
comment on column public.objectives.short_name is 'Short name or code for the objective (e.g., "A", "Alpha", "Obj 1")';

