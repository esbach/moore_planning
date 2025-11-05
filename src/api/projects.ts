import { supabase } from '@/lib/supabaseClient';
import type { Project, ProjectUser, ProjectUserRole, ProjectUserWithProfile } from '@/types';

export async function listProjects(): Promise<Project[]> {
  const { data, error } = await supabase.from('projects').select('*').order('name');
  if (error) throw error;
  return data as Project[];
}

export async function getProject(id: string): Promise<Project | null> {
  const { data, error } = await supabase.from('projects').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data as Project | null;
}

export async function createProject(name: string, description: string | null = null): Promise<Project> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('User must be authenticated to create a project');
  
  // Create project and auto-assign creator as admin
  const { data: project, error: projectError } = await supabase
    .from('projects')
    .insert({ name, description, created_by: user.id })
    .select('*')
    .single();
  
  if (projectError) throw projectError;
  
  // Auto-assign creator to the project with admin role
  const { error: assignError } = await supabase
    .from('project_users')
    .insert({ project_id: project.id, user_id: user.id, role: 'admin' });
  
  if (assignError) {
    // If assignment fails, the project is still created, but user won't have access
    // This shouldn't happen, but log it for debugging
    console.error('Failed to auto-assign creator to project:', assignError);
  }
  
  return project as Project;
}

export async function updateProject(id: string, patch: Partial<Project>): Promise<Project> {
  const { data, error } = await supabase.from('projects').update(patch).eq('id', id).select('*').single();
  if (error) throw error;
  return data as Project;
}

export async function deleteProject(id: string): Promise<void> {
  const { error } = await supabase.from('projects').delete().eq('id', id);
  if (error) throw error;
}

// Check if current user is a project admin (project lead)
export async function isProjectAdmin(projectId: string): Promise<boolean> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;
  
  const { data, error } = await supabase
    .from('project_users')
    .select('role')
    .eq('project_id', projectId)
    .eq('user_id', user.id)
    .maybeSingle();
  
  if (error || !data) return false;
  return data.role === 'admin';
}

// Get current user's role in a project
export async function getCurrentUserProjectRole(projectId: string): Promise<ProjectUserRole | null> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  
  const { data, error } = await supabase
    .from('project_users')
    .select('role')
    .eq('project_id', projectId)
    .eq('user_id', user.id)
    .maybeSingle();
  
  if (error || !data) return null;
  return data.role as ProjectUserRole;
}

// Project-User assignment functions
export async function getProjectUsers(projectId: string): Promise<ProjectUserWithProfile[]> {
  const { data, error } = await supabase
    .from('project_users')
    .select(`
      *,
      profile:profiles!user_id(*)
    `)
    .eq('project_id', projectId)
    .order('created_at');
  
  if (error) throw error;
  return data as ProjectUserWithProfile[];
}

export async function assignUserToProject(
  projectId: string,
  userId: string,
  role: ProjectUserRole = 'viewer'
): Promise<ProjectUser> {
  const { data, error } = await supabase
    .from('project_users')
    .insert({ project_id: projectId, user_id: userId, role })
    .select('*')
    .single();
  
  if (error) throw error;
  return data as ProjectUser;
}

export async function updateProjectUserRole(
  projectId: string,
  userId: string,
  role: ProjectUserRole
): Promise<ProjectUser> {
  const { data, error } = await supabase
    .from('project_users')
    .update({ role })
    .eq('project_id', projectId)
    .eq('user_id', userId)
    .select('*')
    .single();
  
  if (error) throw error;
  return data as ProjectUser;
}

export async function removeUserFromProject(projectId: string, userId: string): Promise<void> {
  const { error } = await supabase
    .from('project_users')
    .delete()
    .eq('project_id', projectId)
    .eq('user_id', userId);
  
  if (error) throw error;
}
