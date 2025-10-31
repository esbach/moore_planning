import { supabase } from '@/lib/supabaseClient';
import type { Outcome } from '@/types';

export async function listOutcomes(projectId?: string): Promise<Outcome[]> {
  let query = supabase.from('outcomes').select('*');
  if (projectId) {
    query = query.eq('project_id', projectId);
  }
  const { data, error } = await query.order('title');
  if (error) throw error;
  return data as Outcome[];
}

export async function createOutcome(projectId: string, title: string, description: string | null = null): Promise<Outcome> {
  const { data, error } = await supabase.from('outcomes').insert({ project_id: projectId, title, description }).select('*').single();
  if (error) throw error;
  return data as Outcome;
}

export async function updateOutcome(id: string, patch: Partial<Outcome>): Promise<Outcome> {
  const { data, error } = await supabase.from('outcomes').update(patch).eq('id', id).select('*').single();
  if (error) throw error;
  return data as Outcome;
}

export async function deleteOutcome(id: string): Promise<void> {
  const { error } = await supabase.from('outcomes').delete().eq('id', id);
  if (error) throw error;
}


