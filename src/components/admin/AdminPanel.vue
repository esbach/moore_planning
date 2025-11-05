<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { listProjects, createProject, getProjectUsers, assignUserToProject, updateProjectUserRole, removeUserFromProject } from '@/api/projects';
import { listProfiles } from '@/api/profiles';
import { createOutcome } from '@/api/outcomes';
import { supabase } from '@/lib/supabaseClient';
import type { Project, Profile, ProjectUserWithProfile, ProjectUserRole } from '@/types';
import Modal from '@/components/common/Modal.vue';

const auth = useAuthStore();
const dataStore = useDataStore();

const props = defineProps<{
  show: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
}>();

const activeTab = ref<'projects' | 'users' | 'assignments'>('projects');
const projects = ref<Project[]>([]);
const users = ref<Profile[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);

// Project creation
const showCreateProjectForm = ref(false);
const newProjectName = ref('');
const newProjectDescription = ref('');
const createOutcomeOnProject = ref(true);
const newOutcomeTitle = ref('');

// User creation
const showCreateUserForm = ref(false);
const newUserEmail = ref('');
const newUserPassword = ref('');
const newUserFullName = ref('');
const newUserIsAdmin = ref(false);

// Project-User assignments
const selectedProjectForAssignment = ref<string>('');
const projectUsers = ref<ProjectUserWithProfile[]>([]);
const selectedUserIdForAssignment = ref<string>('');
const selectedRoleForAssignment = ref<ProjectUserRole>('viewer');

const isAdmin = computed(() => auth.profile?.is_admin === true);

// Project users map for quick lookup
const projectUsersMap = computed(() => {
  const map = new Map<string, ProjectUserWithProfile[]>();
  projects.value.forEach(project => {
    // We'll load this when needed
  });
  return map;
});

watch(() => props.show, async (newVal) => {
  if (newVal && isAdmin.value) {
    await loadData();
  }
});

onMounted(async () => {
  if (props.show && isAdmin.value) {
    await loadData();
  }
});

async function loadData() {
  loading.value = true;
  error.value = null;
  
  try {
    const [projectsData, usersData] = await Promise.all([
      listProjects(),
      listProfiles(),
    ]);
    
    projects.value = projectsData;
    users.value = usersData;
  } catch (e: any) {
    console.error('Failed to load data:', e);
    error.value = e?.message || 'Failed to load data';
  } finally {
    loading.value = false;
  }
}

async function loadProjectUsers(projectId: string) {
  try {
    const data = await getProjectUsers(projectId);
    projectUsers.value = data;
  } catch (e: any) {
    console.error('Failed to load project users:', e);
    error.value = e?.message || 'Failed to load project users';
  }
}

watch(() => selectedProjectForAssignment.value, async (projectId) => {
  if (projectId) {
    await loadProjectUsers(projectId);
  } else {
    projectUsers.value = [];
  }
});

async function handleCreateProject() {
  if (!newProjectName.value.trim()) {
    error.value = 'Project name is required';
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    const project = await createProject(
      newProjectName.value.trim(),
      newProjectDescription.value.trim() || null
    );
    
    // If creating outcome, do that too
    if (createOutcomeOnProject.value && newOutcomeTitle.value.trim()) {
      try {
        await createOutcome(
          project.id,
          newOutcomeTitle.value.trim()
        );
      } catch (e) {
        console.warn('Failed to create initial outcome:', e);
        // Don't fail the whole operation
      }
    }
    
    // Reset form
    newProjectName.value = '';
    newProjectDescription.value = '';
    newOutcomeTitle.value = '';
    createOutcomeOnProject.value = true;
    showCreateProjectForm.value = false;
    
    // Refresh data
    await loadData();
    await dataStore.refreshProjects();
    await dataStore.refreshOutcomes();
    
    error.value = null;
  } catch (e: any) {
    console.error('Failed to create project:', e);
    error.value = e?.message || 'Failed to create project';
  } finally {
    loading.value = false;
  }
}

async function handleCreateUser() {
  if (!newUserEmail.value || !newUserPassword.value) {
    error.value = 'Email and password are required';
    return;
  }
  
  if (newUserPassword.value.length < 6) {
    error.value = 'Password must be at least 6 characters';
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    const supabaseUrl = (import.meta as any).env.VITE_SUPABASE_URL;
    const supabaseAnonKey = (import.meta as any).env.VITE_SUPABASE_ANON_KEY;
    
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      throw new Error('Not authenticated');
    }
    
    const response = await fetch(`${supabaseUrl}/functions/v1/create-user`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${session.access_token}`,
        'apikey': supabaseAnonKey,
      },
      body: JSON.stringify({
        email: newUserEmail.value,
        password: newUserPassword.value,
        full_name: newUserFullName.value || null,
        is_admin: newUserIsAdmin.value,
      }),
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to create user');
    }
    
    // Reset form
    newUserEmail.value = '';
    newUserPassword.value = '';
    newUserFullName.value = '';
    newUserIsAdmin.value = false;
    showCreateUserForm.value = false;
    
    // Refresh users
    await loadData();
  } catch (e: any) {
    console.error('Failed to create user:', e);
    error.value = e?.message || 'Failed to create user';
  } finally {
    loading.value = false;
  }
}

async function handleAssignUser() {
  if (!selectedProjectForAssignment.value || !selectedUserIdForAssignment.value) {
    error.value = 'Please select a project and user';
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    await assignUserToProject(
      selectedProjectForAssignment.value,
      selectedUserIdForAssignment.value,
      selectedRoleForAssignment.value
    );
    
    await loadProjectUsers(selectedProjectForAssignment.value);
    selectedUserIdForAssignment.value = '';
    selectedRoleForAssignment.value = 'viewer';
  } catch (e: any) {
    console.error('Failed to assign user:', e);
    error.value = e?.message || 'Failed to assign user';
  } finally {
    loading.value = false;
  }
}

async function handleUpdateRole(projectId: string, userId: string, newRole: ProjectUserRole) {
  loading.value = true;
  error.value = null;
  
  try {
    await updateProjectUserRole(projectId, userId, newRole);
    await loadProjectUsers(projectId);
  } catch (e: any) {
    console.error('Failed to update role:', e);
    error.value = e?.message || 'Failed to update role';
  } finally {
    loading.value = false;
  }
}

async function handleRemoveUser(projectId: string, userId: string) {
  if (!confirm('Are you sure you want to remove this user from the project?')) {
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    await removeUserFromProject(projectId, userId);
    await loadProjectUsers(projectId);
  } catch (e: any) {
    console.error('Failed to remove user:', e);
    error.value = e?.message || 'Failed to remove user';
  } finally {
    loading.value = false;
  }
}

function getUserName(user: Profile): string {
  return user.full_name || user.email || 'Unknown User';
}

function getRoleColor(role: ProjectUserRole): string {
  switch (role) {
    case 'admin':
      return 'bg-purple-100 text-purple-800';
    case 'editor':
      return 'bg-blue-100 text-blue-800';
    case 'viewer':
      return 'bg-gray-100 text-gray-800';
    default:
      return 'bg-gray-100 text-gray-800';
  }
}

// Get users assigned to a project (for display)
const getUsersForProject = computed(() => {
  return (projectId: string) => {
    return projectUsers.value.filter(pu => pu.project_id === projectId);
  };
});

// Project visibility in sidebar (for admins) - make it reactive
// We track HIDDEN projects (inverted logic for easier initialization)
// Use array instead of Set for better Vue reactivity
const hiddenProjectIds = ref<string[]>([]);

function getHiddenProjectIds(): string[] {
  if (!isAdmin.value) return []; // Not an admin, don't use this feature
  const stored = localStorage.getItem('hidden_project_ids');
  if (!stored) return []; // Default: show all (nothing hidden)
  try {
    const parsed = JSON.parse(stored);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function loadHiddenProjectIds() {
  hiddenProjectIds.value = getHiddenProjectIds();
}

// Check if project is visible (not hidden)
const isProjectVisibleInSidebar = (projectId: string): boolean => {
  if (!isAdmin.value) return true; // Non-admins always see all their projects
  return !hiddenProjectIds.value.includes(projectId); // Visible if NOT in hidden array
};

function toggleProjectVisibility(projectId: string) {
  if (!isAdmin.value) return;
  const hiddenIds = [...hiddenProjectIds.value]; // Create new array for reactivity
  const index = hiddenIds.indexOf(projectId);
  if (index > -1) {
    // Currently hidden, make it visible
    hiddenIds.splice(index, 1);
  } else {
    // Currently visible, hide it
    hiddenIds.push(projectId);
  }
  hiddenProjectIds.value = hiddenIds; // Update reactive state immediately (new array reference)
  localStorage.setItem('hidden_project_ids', JSON.stringify(hiddenIds));
  // Force reactivity update by triggering a custom event for sidebar
  window.dispatchEvent(new CustomEvent('projectVisibilityChanged', { detail: { projectId } }));
}

// Load visibility preferences when component mounts or admin panel opens
watch(() => props.show, (newVal) => {
  if (newVal && isAdmin.value) {
    loadHiddenProjectIds();
  }
}, { immediate: true });

onMounted(() => {
  if (isAdmin.value) {
    loadHiddenProjectIds();
  }
});
</script>

<template>
  <Modal :open="show" size="half" @close="emit('close')">
    <div class="w-full max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-semibold text-gray-900">Admin Panel</h2>
        <button
          @click="emit('close')"
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      
      <!-- Tabs -->
      <div class="border-b border-gray-200 mb-6">
        <nav class="-mb-px flex space-x-8">
          <button
            @click="activeTab = 'projects'"
            :class="[
              'py-2 px-1 border-b-2 font-medium text-sm',
              activeTab === 'projects'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            ]"
          >
            Projects
          </button>
          <button
            @click="activeTab = 'users'"
            :class="[
              'py-2 px-1 border-b-2 font-medium text-sm',
              activeTab === 'users'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            ]"
          >
            Users
          </button>
          <button
            @click="activeTab = 'assignments'"
            :class="[
              'py-2 px-1 border-b-2 font-medium text-sm',
              activeTab === 'assignments'
                ? 'border-blue-500 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            ]"
          >
            Project Assignments
          </button>
        </nav>
      </div>
      
      <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-800 text-sm">
        {{ error }}
      </div>
      
      <!-- Projects Tab -->
      <div v-if="activeTab === 'projects'" class="space-y-6">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">All Projects</h3>
          <button
            @click="showCreateProjectForm = !showCreateProjectForm"
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
          >
            + Create Project
          </button>
        </div>
        
        <!-- Create Project Form -->
        <div v-if="showCreateProjectForm" class="p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-4">
          <h4 class="font-semibold text-gray-900">Create New Project</h4>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Project Name *</label>
            <input
              v-model="newProjectName"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Enter project name"
            />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              v-model="newProjectDescription"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
              placeholder="Optional description"
              rows="2"
            />
          </div>
          
          <div class="space-y-2">
            <label class="flex items-center gap-2">
              <input
                v-model="createOutcomeOnProject"
                type="checkbox"
                class="w-4 h-4 text-blue-600 border-gray-300 rounded"
              />
              <span class="text-sm font-medium text-gray-700">Create initial outcome</span>
            </label>
            
            <div v-if="createOutcomeOnProject" class="ml-6">
              <input
                v-model="newOutcomeTitle"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                placeholder="Outcome title"
              />
            </div>
          </div>
          
          <div class="flex gap-2">
            <button
              @click="showCreateProjectForm = false; newProjectName = ''; newProjectDescription = ''; newOutcomeTitle = ''; error = null"
              class="flex-1 px-4 py-2 text-gray-700 bg-gray-100 rounded hover:bg-gray-200 transition-colors"
            >
              Cancel
            </button>
            <button
              @click="handleCreateProject"
              :disabled="loading || !newProjectName.trim()"
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              Create Project
            </button>
          </div>
        </div>
        
        <!-- Projects List -->
        <div v-if="loading && projects.length === 0" class="text-center py-8 text-gray-500">
          Loading projects...
        </div>
        
        <div v-else-if="projects.length === 0" class="text-center py-8 text-gray-500">
          No projects yet. Create one to get started!
        </div>
        
        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div
            v-for="project in projects"
            :key="project.id"
            class="p-4 bg-white rounded-lg border border-gray-200 hover:shadow-md transition-shadow"
          >
            <div class="flex items-start justify-between mb-2">
              <h4 class="font-semibold text-gray-900 flex-1">{{ project.name }}</h4>
              <button
                @click="toggleProjectVisibility(project.id)"
                class="ml-2 p-1.5 rounded hover:bg-gray-100 transition-colors"
                :title="isProjectVisibleInSidebar(project.id) ? 'Hide from sidebar' : 'Show in sidebar'"
              >
                <svg 
                  class="w-5 h-5"
                  :class="isProjectVisibleInSidebar(project.id) ? 'text-blue-600' : 'text-gray-400'"
                  fill="none" 
                  stroke="currentColor" 
                  viewBox="0 0 24 24"
                >
                  <path 
                    v-if="isProjectVisibleInSidebar(project.id)"
                    stroke-linecap="round" 
                    stroke-linejoin="round" 
                    stroke-width="2" 
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" 
                  />
                  <path 
                    stroke-linecap="round" 
                    stroke-linejoin="round" 
                    stroke-width="2" 
                    :d="isProjectVisibleInSidebar(project.id) 
                      ? 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z M15 12a3 3 0 11-6 0 3 3 0 016 0z'
                      : 'M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21'" 
                  />
                </svg>
              </button>
            </div>
            <p v-if="project.description" class="text-sm text-gray-600 mb-2">{{ project.description }}</p>
            <div class="flex items-center justify-between">
              <p class="text-xs text-gray-500">Created: {{ new Date(project.created_at).toLocaleDateString() }}</p>
              <span 
                v-if="isAdmin"
                class="text-xs px-2 py-0.5 rounded"
                :class="isProjectVisibleInSidebar(project.id) 
                  ? 'bg-green-100 text-green-800' 
                  : 'bg-gray-100 text-gray-600'"
              >
                {{ isProjectVisibleInSidebar(project.id) ? 'Visible' : 'Hidden' }}
              </span>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Users Tab -->
      <div v-if="activeTab === 'users'" class="space-y-6">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">All Users</h3>
          <button
            @click="showCreateUserForm = !showCreateUserForm"
            class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
          >
            + Create User
          </button>
        </div>
        
        <!-- Create User Form -->
        <div v-if="showCreateUserForm" class="p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-3">
          <h4 class="font-semibold text-gray-900">Create New User</h4>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
            <input
              v-model="newUserEmail"
              type="email"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="user@example.com"
            />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Password *</label>
            <input
              v-model="newUserPassword"
              type="password"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Minimum 6 characters"
            />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
            <input
              v-model="newUserFullName"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Optional"
            />
          </div>
          
          <div class="flex items-center gap-2">
            <input
              v-model="newUserIsAdmin"
              type="checkbox"
              id="isAdmin"
              class="w-4 h-4 text-blue-600 border-gray-300 rounded"
            />
            <label for="isAdmin" class="text-sm font-medium text-gray-700">Global Admin</label>
          </div>
          
          <div class="flex gap-2">
            <button
              @click="showCreateUserForm = false; newUserEmail = ''; newUserPassword = ''; newUserFullName = ''; newUserIsAdmin = false; error = null"
              class="flex-1 px-4 py-2 text-gray-700 bg-gray-100 rounded hover:bg-gray-200 transition-colors"
            >
              Cancel
            </button>
            <button
              @click="handleCreateUser"
              :disabled="loading || !newUserEmail || !newUserPassword"
              class="flex-1 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              Create User
            </button>
          </div>
        </div>
        
        <!-- Users List -->
        <div v-if="loading && users.length === 0" class="text-center py-8 text-gray-500">
          Loading users...
        </div>
        
        <div v-else-if="users.length === 0" class="text-center py-8 text-gray-500">
          No users found.
        </div>
        
        <div v-else class="space-y-2">
          <div
            v-for="user in users"
            :key="user.id"
            class="p-3 bg-white rounded-lg border border-gray-200"
          >
            <div class="flex items-center justify-between">
              <div>
                <div class="flex items-center gap-2">
                  <span class="font-medium text-gray-900">{{ getUserName(user) }}</span>
                  <span
                    v-if="user.is_admin"
                    class="px-2 py-0.5 text-xs font-medium rounded bg-purple-100 text-purple-800"
                  >
                    Admin
                  </span>
                </div>
                <p class="text-sm text-gray-500">{{ user.email }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Assignments Tab -->
      <div v-if="activeTab === 'assignments'" class="space-y-6">
        <h3 class="text-lg font-semibold">Project-User Assignments</h3>
        
        <!-- Project Selector -->
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Select Project</label>
          <select
            v-model="selectedProjectForAssignment"
            class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            @change="loadProjectUsers(selectedProjectForAssignment)"
          >
            <option value="">Choose a project...</option>
            <option
              v-for="project in projects"
              :key="project.id"
              :value="project.id"
            >
              {{ project.name }}
            </option>
          </select>
        </div>
        
        <!-- Assign User Form -->
        <div v-if="selectedProjectForAssignment" class="p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-3">
          <h4 class="font-semibold text-gray-900">Assign User to Project</h4>
          
          <div class="flex gap-2">
            <select
              v-model="selectedUserIdForAssignment"
              class="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select a user...</option>
              <option
                v-for="user in users"
                :key="user.id"
                :value="user.id"
                :disabled="projectUsers.some(pu => pu.user_id === user.id)"
              >
                {{ getUserName(user) }} ({{ user.email }})
                <template v-if="projectUsers.some(pu => pu.user_id === user.id)"> - Already assigned</template>
              </option>
            </select>
            
            <select
              v-model="selectedRoleForAssignment"
              class="px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="viewer">Viewer</option>
              <option value="editor">Editor</option>
              <option value="admin">Admin</option>
            </select>
            
            <button
              @click="handleAssignUser"
              :disabled="!selectedUserIdForAssignment || loading"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              Assign
            </button>
          </div>
        </div>
        
        <!-- Project Users List -->
        <div v-if="selectedProjectForAssignment && projectUsers.length > 0" class="space-y-2">
          <h4 class="font-semibold text-gray-900">Users in Project</h4>
          <div
            v-for="projectUser in projectUsers"
            :key="projectUser.id"
            class="p-3 bg-white rounded-lg border border-gray-200"
          >
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <div class="flex items-center gap-2 mb-1">
                  <span class="font-medium text-gray-900">
                    {{ getUserName(projectUser.profile) }}
                  </span>
                  <span
                    class="px-2 py-0.5 text-xs font-medium rounded"
                    :class="getRoleColor(projectUser.role)"
                  >
                    {{ projectUser.role }}
                  </span>
                </div>
                <div class="text-xs text-gray-500">
                  {{ projectUser.profile.email }}
                </div>
              </div>
              
              <div class="flex items-center gap-2">
                <select
                  :value="projectUser.role"
                  @change="handleUpdateRole(projectUser.project_id, projectUser.user_id, ($event.target as HTMLSelectElement).value as ProjectUserRole)"
                  class="px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                  :disabled="loading"
                >
                  <option value="viewer">Viewer</option>
                  <option value="editor">Editor</option>
                  <option value="admin">Admin</option>
                </select>
                
                <button
                  @click="handleRemoveUser(projectUser.project_id, projectUser.user_id)"
                  class="px-3 py-1 text-sm text-red-600 hover:bg-red-50 rounded transition-colors"
                  :disabled="loading"
                  title="Remove user"
                >
                  Remove
                </button>
              </div>
            </div>
          </div>
        </div>
        
        <!-- All Projects Overview -->
        <div class="mt-8">
          <h4 class="font-semibold text-gray-900 mb-4">All Projects Overview</h4>
          <div class="space-y-4">
            <div
              v-for="project in projects"
              :key="project.id"
              class="p-4 bg-white rounded-lg border border-gray-200"
            >
              <h5 class="font-semibold text-gray-900 mb-2">{{ project.name }}</h5>
              <div class="text-sm text-gray-600">
                <p class="mb-2">Click "Select Project" above to view and manage users for this project.</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>

