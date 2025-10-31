import { supabase } from '@/lib/supabaseClient';
import type { Profile } from '@/types';

export async function listProfiles(): Promise<Profile[]> {
  const { data, error } = await supabase.from('profiles').select('*').order('full_name', { nullsFirst: true });
  if (error) throw error;
  return data as Profile[];
}


