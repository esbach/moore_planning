import { supabase } from '@/lib/supabaseClient';
import type { Output } from '@/types';

export async function listOutputs(objectiveId: string): Promise<Output[]> {
  const { data, error } = await supabase
    .from('outputs')
    .select('*')
    .eq('objective_id', objectiveId)
    .order('index', { nullsFirst: true })
    .order('title');
  if (error) throw error;
  return data as Output[];
}

export async function createOutput(objectiveId: string, title: string): Promise<Output> {
  const { data, error } = await supabase
    .from('outputs')
    .insert({ objective_id: objectiveId, title })
    .select('*')
    .single();
  if (error) throw error;
  return data as Output;
}

export async function updateOutput(id: string, patch: Partial<Output>): Promise<Output> {
  const { data, error } = await supabase
    .from('outputs')
    .update(patch)
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw error;
  return data as Output;
}

export async function deleteOutput(id: string): Promise<void> {
  const { error } = await supabase.from('outputs').delete().eq('id', id);
  if (error) throw error;
}


