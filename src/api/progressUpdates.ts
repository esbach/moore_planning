import { supabase } from '@/lib/supabaseClient';
import type { ProgressUpdate } from '@/types';

export async function listProgressUpdates(activityId: string): Promise<ProgressUpdate[]> {
  const { data, error } = await supabase
    .from('progress_updates')
    .select('*')
    .eq('activity_id', activityId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data as ProgressUpdate[];
}

export async function createProgressUpdate(
  activityId: string,
  reportedBy: string,
  progress: number,
  status: string,
  notes: string | null = null
): Promise<ProgressUpdate> {
  const { data, error } = await supabase
    .from('progress_updates')
    .insert({
      activity_id: activityId,
      reported_by: reportedBy,
      progress,
      status,
      notes,
    })
    .select('*')
    .single();
  if (error) throw error;
  return data as ProgressUpdate;
}

export async function deleteProgressUpdate(id: string): Promise<void> {
  const { error } = await supabase.from('progress_updates').delete().eq('id', id);
  if (error) throw error;
}

