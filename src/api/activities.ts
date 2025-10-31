import { supabase } from '@/lib/supabaseClient';
import type { Activity } from '@/types';

export async function listAllActivities(): Promise<Activity[]> {
  const { data, error } = await supabase
    .from('activities')
    .select('*')
    .order('start_date', { nullsFirst: true })
    .order('title');
  if (error) throw error;
  return data as Activity[];
}

export async function listActivities(outputId: string): Promise<Activity[]> {
  const { data, error } = await supabase
    .from('activities')
    .select('*')
    .eq('output_id', outputId)
    .order('start_date', { nullsFirst: true })
    .order('title');
  if (error) throw error;
  return data as Activity[];
}

export async function createActivity(payload: Omit<Activity, 'id'> & { id?: string }): Promise<Activity> {
  const { id, ...rest } = payload as any;
  const { data, error } = await supabase
    .from('activities')
    .insert(rest)
    .select('*')
    .single();
  if (error) throw error;
  return data as Activity;
}

export async function updateActivity(id: string, patch: Partial<Activity>): Promise<Activity> {
  const { data, error } = await supabase
    .from('activities')
    .update(patch)
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return data as Activity;
}

export async function deleteActivity(id: string): Promise<void> {
  const { error } = await supabase.from('activities').delete().eq('id', id);
  if (error) throw error;
}


