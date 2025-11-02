-- Update status from 4-status to 5-status scale
-- Old: not_started, in_progress, blocked, done
-- New: not_started, started, in_progress, review, complete

-- Update activities table constraint
alter table public.activities 
  drop constraint if exists activities_status_check;

alter table public.activities
  add constraint activities_status_check 
  check (status in ('not_started','started','in_progress','review','complete'));

-- Update progress_updates table constraint
alter table public.progress_updates 
  drop constraint if exists progress_updates_status_check;

alter table public.progress_updates
  add constraint progress_updates_status_check 
  check (status in ('not_started','started','in_progress','review','complete'));

-- Migrate existing data
-- Map old statuses to new ones
update public.activities 
set status = case 
  when status = 'blocked' then 'review'
  when status = 'done' then 'complete'
  else status
end
where status in ('blocked', 'done');

update public.progress_updates
set status = case 
  when status = 'blocked' then 'review'
  when status = 'done' then 'complete'
  else status
end
where status in ('blocked', 'done');


