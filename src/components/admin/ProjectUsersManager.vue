<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { useProjectStore } from '@/stores/project';
import {
  getProjectUsers,
  assignUserToProject,
  updateProjectUserRole,
  removeUserFromProject,
} from '@/api/projects';
import { listProfiles } from '@/api/profiles';
import type { ProjectUserWithProfile, ProjectUserRole, Profile } from '@/types';
import Modal from '@/components/common/Modal.vue';

const auth = useAuthStore();
const dataStore = useDataStore();
const projectStore = useProjectStore();

const props = defineProps<{
  projectId: string | null;
  show: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
}>();

const projectUsers = ref<ProjectUserWithProfile[]>([]);
const allUsers = ref<Profile[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);

const selectedUserId = ref<string>('');
const selectedRole = ref<ProjectUserRole>('viewer');

const availableUsers = computed(() => {
  if (!props.projectId) return [];
  const assignedUserIds = new Set(projectUsers.value.map(pu => pu.user_id));
  return allUsers.value.filter(user => !assignedUserIds.has(user.id));
});

const isAdmin = computed(() => auth.profile?.is_admin === true);

watch(() => props.show, async (newVal) => {
  if (newVal && props.projectId && isAdmin.value) {
    await loadData();
  }
});

onMounted(async () => {
  if (props.show && props.projectId && isAdmin.value) {
    await loadData();
  }
});

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
  if (!props.projectId || !selectedUserId.value) return;
  
  loading.value = true;
  error.value = null;
  
  try {
    await assignUserToProject(props.projectId, selectedUserId.value, selectedRole.value);
    await loadData();
    selectedUserId.value = '';
    selectedRole.value = 'viewer';
  } catch (e: any) {
    console.error('Failed to assign user:', e);
    error.value = e?.message || 'Failed to assign user';
  } finally {
    loading.value = false;
  }
}

async function handleUpdateRole(projectUserId: string, userId: string, newRole: ProjectUserRole) {
  if (!props.projectId) return;
  
  loading.value = true;
  error.value = null;
  
  try {
    await updateProjectUserRole(props.projectId, userId, newRole);
    await loadData();
  } catch (e: any) {
    console.error('Failed to update role:', e);
    error.value = e?.message || 'Failed to update role';
  } finally {
    loading.value = false;
  }
}

async function handleRemoveUser(userId: string) {
  if (!props.projectId) return;
  
  if (!confirm('Are you sure you want to remove this user from the project?')) {
    return;
  }
  
  loading.value = true;
  error.value = null;
  
  try {
    await removeUserFromProject(props.projectId, userId);
    await loadData();
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
</script>

<template>
  <Modal :open="show" @close="emit('close')">
    <div class="w-full max-w-2xl">
      <h2 class="text-xl font-semibold text-gray-900 mb-4">Manage Project Users</h2>
      
      <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-800 text-sm">
        {{ error }}
      </div>
      
      <div v-if="loading && projectUsers.length === 0" class="text-center py-8 text-gray-500">
        Loading...
      </div>
      
      <div v-else>
        <!-- Current Project Users -->
        <div class="mb-6">
          <h3 class="text-sm font-semibold text-gray-700 mb-3">Assigned Users</h3>
          
          <div v-if="projectUsers.length === 0" class="text-sm text-gray-500 italic py-4">
            No users assigned to this project yet.
          </div>
          
          <div v-else class="space-y-2">
            <div
              v-for="projectUser in projectUsers"
              :key="projectUser.id"
              class="flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-200"
            >
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
                  @change="handleUpdateRole(projectUser.id, projectUser.user_id, ($event.target as HTMLSelectElement).value as ProjectUserRole)"
                  class="px-2 py-1 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                  :disabled="loading"
                >
                  <option value="viewer">Viewer</option>
                  <option value="editor">Editor</option>
                  <option value="admin">Admin</option>
                </select>
                
                <button
                  @click="handleRemoveUser(projectUser.user_id)"
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
        
        <!-- Add New User -->
        <div class="border-t pt-6">
          <h3 class="text-sm font-semibold text-gray-700 mb-3">Add User to Project</h3>
          
          <div v-if="availableUsers.length === 0" class="text-sm text-gray-500 italic py-4">
            All users are already assigned to this project.
          </div>
          
          <div v-else class="flex gap-3">
            <select
              v-model="selectedUserId"
              class="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              :disabled="loading"
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
              v-model="selectedRole"
              class="px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
              :disabled="loading"
            >
              <option value="viewer">Viewer</option>
              <option value="editor">Editor</option>
              <option value="admin">Admin</option>
            </select>
            
            <button
              @click="handleAssignUser"
              :disabled="!selectedUserId || loading"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              Add
            </button>
          </div>
        </div>
      </div>
      
      <div class="mt-6 flex justify-end">
        <button
          @click="emit('close')"
          class="px-4 py-2 text-gray-700 bg-gray-100 rounded hover:bg-gray-200 transition-colors"
        >
          Close
        </button>
      </div>
    </div>
  </Modal>
</template>

