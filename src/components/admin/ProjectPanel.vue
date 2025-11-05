<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { useProjectStore } from '@/stores/project';
import { getProjectUsers, assignUserToProject, updateProjectUserRole, removeUserFromProject, isProjectAdmin } from '@/api/projects';
import { listProfiles } from '@/api/profiles';
import { createOutcome } from '@/api/outcomes';
import { supabase } from '@/lib/supabaseClient';
import type { Profile, ProjectUserWithProfile, ProjectUserRole } from '@/types';
import Modal from '@/components/common/Modal.vue';

const auth = useAuthStore();
const dataStore = useDataStore();
const projectStore = useProjectStore();

const props = defineProps<{
  show: boolean;
  projectId: string | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
}>();

const projectUsers = ref<ProjectUserWithProfile[]>([]);
const allUsers = ref<Profile[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const userIsProjectAdmin = ref(false);

// User assignment
const selectedUserIdForAssignment = ref<string>('');
const selectedRoleForAssignment = ref<ProjectUserRole>('viewer');

// Outcome creation
const showCreateOutcomeForm = ref(false);
const newOutcomeTitle = ref('');

// User creation
const showCreateUserForm = ref(false);
const newUserEmail = ref('');
const newUserPassword = ref('');
const newUserFullName = ref('');
const newUserRole = ref<ProjectUserRole>('viewer');

watch(() => props.show, async (newVal) => {
  if (newVal && props.projectId) {
    await checkProjectAdminStatus();
    await loadData();
  }
});

onMounted(async () => {
  if (props.show && props.projectId) {
    await checkProjectAdminStatus();
    await loadData();
  }
});

async function checkProjectAdminStatus() {
  if (!props.projectId) return;
  try {
    userIsProjectAdmin.value = await isProjectAdmin(props.projectId);
  } catch (e) {
    console.error('Failed to check project admin status:', e);
    userIsProjectAdmin.value = false;
  }
}

async function loadData() {
  if (!props.projectId) return;
  
  loading.value = true;
  error.value = null;
  
  try {
    const [usersData, projectUsersData] = await Promise.all([
      listProfiles(),
      getProjectUsers(props.projectId),
    ]);
    
    allUsers.value = usersData;
    projectUsers.value = projectUsersData;
  } catch (e: any) {
    console.error('Failed to load data:', e);
    error.value = e?.message || 'Failed to load data';
  } finally {
    loading.value = false;
  }
}

async function handleAssignUser() {
  if (!props.projectId || !selectedUserIdForAssignment.value) {
    error.value = 'Please select a user';
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    await assignUserToProject(
      props.projectId,
      selectedUserIdForAssignment.value,
      selectedRoleForAssignment.value
    );
    
    await loadData();
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
    await loadData();
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
    await loadData();
  } catch (e: any) {
    console.error('Failed to remove user:', e);
    error.value = e?.message || 'Failed to remove user';
  } finally {
    loading.value = false;
  }
}

async function handleCreateOutcome() {
  if (!props.projectId || !newOutcomeTitle.value.trim()) {
    error.value = 'Outcome title is required';
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    await createOutcome(props.projectId, newOutcomeTitle.value.trim());
    newOutcomeTitle.value = '';
    showCreateOutcomeForm.value = false;
    await dataStore.refreshOutcomes();
  } catch (e: any) {
    console.error('Failed to create outcome:', e);
    error.value = e?.message || 'Failed to create outcome';
  } finally {
    loading.value = false;
  }
}

async function handleCreateUser() {
  if (!props.projectId || !newUserEmail.value || !newUserPassword.value) {
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
    
    // Call Supabase Edge Function to create user
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
        is_admin: false, // Project leads can't create global admins
        project_id: props.projectId, // Automatically assign to this project
        project_role: newUserRole.value,
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
    newUserRole.value = 'viewer';
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

const availableUsers = computed(() => {
  if (!props.projectId) return [];
  const assignedUserIds = new Set(projectUsers.value.map(pu => pu.user_id));
  return allUsers.value.filter(user => !assignedUserIds.has(user.id));
});

const currentProject = computed(() => {
  return projectStore.currentProject;
});
</script>

<template>
  <Modal :open="show" size="full" @close="emit('close')">
    <div class="w-full max-h-[90vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-2xl font-semibold text-gray-900">Project Management</h2>
          <p v-if="currentProject" class="text-sm text-gray-600 mt-1">{{ currentProject.name }}</p>
        </div>
        <button
          @click="emit('close')"
          class="text-gray-400 hover:text-gray-600"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      
      <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-800 text-sm">
        {{ error }}
      </div>
      
      <div v-if="!userIsProjectAdmin" class="text-center py-8 text-gray-500">
        <p>You don't have admin permissions for this project.</p>
        <p class="text-sm mt-2">Only project leads can manage this project.</p>
      </div>
      
      <div v-else class="space-y-6">
        <!-- Project Users Section -->
        <div>
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-semibold">Project Users</h3>
            <button
              @click="showCreateUserForm = !showCreateUserForm"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
            >
              + Create User
            </button>
          </div>
          
          <!-- Create User Form -->
          <div v-if="showCreateUserForm" class="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
            <h4 class="font-semibold text-gray-900 mb-3">Create New User</h4>
            
            <div class="space-y-3">
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
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Project Role</label>
                <select
                  v-model="newUserRole"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="viewer">Viewer</option>
                  <option value="editor">Editor</option>
                  <option value="admin">Admin</option>
                </select>
                <p class="text-xs text-gray-500 mt-1">The user will be automatically assigned to this project with the selected role.</p>
              </div>
            </div>
            
            <div class="flex gap-2 mt-4">
              <button
                @click="showCreateUserForm = false; newUserEmail = ''; newUserPassword = ''; newUserFullName = ''; newUserRole = 'viewer'; error = null"
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
          
          <!-- Assign User Form -->
          <div class="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
            <h4 class="font-semibold text-gray-900 mb-3">Assign User to Project</h4>
            
            <div class="flex gap-2">
              <select
                v-model="selectedUserIdForAssignment"
                class="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">Select a user...</option>
                <option
                  v-for="user in availableUsers"
                  :key="user.id"
                  :value="user.id"
                >
                  {{ getUserName(user) }} ({{ user.email }})
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
          <div v-if="loading && projectUsers.length === 0" class="text-center py-8 text-gray-500">
            Loading users...
          </div>
          
          <div v-else-if="projectUsers.length === 0" class="text-center py-8 text-gray-500">
            No users assigned to this project yet.
          </div>
          
          <div v-else class="space-y-2">
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
                    <span
                      v-if="projectUser.profile.is_admin"
                      class="px-2 py-0.5 text-xs font-medium rounded bg-purple-100 text-purple-800"
                    >
                      Global Admin
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
        </div>
        
        <!-- Outcome Management Section -->
        <div>
          <div class="flex justify-between items-center mb-4">
            <h3 class="text-lg font-semibold">Outcomes</h3>
            <button
              @click="showCreateOutcomeForm = !showCreateOutcomeForm"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
            >
              + Create Outcome
            </button>
          </div>
          
          <!-- Create Outcome Form -->
          <div v-if="showCreateOutcomeForm" class="mb-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
            <h4 class="font-semibold text-gray-900 mb-3">Create New Outcome</h4>
            
            <div class="mb-3">
              <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
              <input
                v-model="newOutcomeTitle"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Outcome title"
                @keydown.enter.prevent="handleCreateOutcome"
              />
            </div>
            
            <div class="flex gap-2">
              <button
                @click="showCreateOutcomeForm = false; newOutcomeTitle = ''; error = null"
                class="flex-1 px-4 py-2 text-gray-700 bg-gray-100 rounded hover:bg-gray-200 transition-colors"
              >
                Cancel
              </button>
              <button
                @click="handleCreateOutcome"
                :disabled="loading || !newOutcomeTitle.trim()"
                class="flex-1 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
              >
                Create Outcome
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>

