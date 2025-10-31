import { supabase } from '@/lib/supabaseClient';
import type { Objective } from '@/types';

export async function listObjectives(outcomeId: string): Promise<Objective[]> {
  const { data, error } = await supabase
    .from('objectives')
    .select('*')
    .eq('outcome_id', outcomeId)
    .order('index', { nullsFirst: true })
    .order('title');
  if (error) throw error;
  return data as Objective[];
}

export async function createObjective(outcomeId: string, title: string): Promise<Objective> {
  const { data, error } = await supabase
    .from('objectives')
    .insert({ outcome_id: outcomeId, title })
    .select('*')
    .single();
  if (error) throw error;
  return data as Objective;
}

export async function updateObjective(id: string, patch: Partial<Objective>): Promise<Objective> {
  const { data, error } = await supabase
    .from('objectives')
    .update(patch)
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return data as Objective;
}

export async function deleteObjective(id: string): Promise<void> {
  const { error } = await supabase.from('objectives').delete().eq('id', id);
  if (error) throw error;
}


