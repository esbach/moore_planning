<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import { listProfiles } from '@/api/profiles';
import { listProjects, assignUserToProject } from '@/api/projects';
import { supabase } from '@/lib/supabaseClient';
import type { Profile, Project } from '@/types';
import Modal from '@/components/common/Modal.vue';

const auth = useAuthStore();
const dataStore = useDataStore();

const props = defineProps<{
  show: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
}>();

const users = ref<Profile[]>([]);
const projects = ref<Project[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);

// New user form
const showCreateUserForm = ref(false);
const newUserEmail = ref('');
const newUserPassword = ref('');
const newUserFullName = ref('');
const newUserIsAdmin = ref(false);
const selectedProjectForNewUser = ref<string>('');
const selectedRoleForNewUser = ref<'viewer' | 'editor' | 'admin'>('viewer');

const isAdmin = computed(() => auth.profile?.is_admin === true);

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
    const [usersData, projectsData] = await Promise.all([
      listProfiles(),
      listProjects(),
    ]);
    
    users.value = usersData;
    projects.value = projectsData;
  } catch (e: any) {
    console.error('Failed to load data:', e);
    error.value = e?.message || 'Failed to load data';
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
    // Get Supabase URL and anon key for the Edge Function
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
    
    // Get current session for auth
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      throw new Error('Not authenticated');
    }
    
    // Call Supabase Edge Function (simpler than Netlify Functions - no service role key needed!)
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
        project_id: selectedProjectForNewUser.value || null,
        project_role: selectedProjectForNewUser.value ? selectedRoleForNewUser.value : null,
      }),
    });
    
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to create user');
    }
    
    const result = await response.json();
    
    // Reset form
    newUserEmail.value = '';
    newUserPassword.value = '';
    newUserFullName.value = '';
    newUserIsAdmin.value = false;
    selectedProjectForNewUser.value = '';
    selectedRoleForNewUser.value = 'viewer';
    showCreateUserForm.value = false;
    
    // Reload users
    await loadData();
  } catch (e: any) {
    console.error('Failed to create user:', e);
    error.value = e?.message || 'Failed to create user. Make sure the Supabase Edge Function is deployed.';
  } finally {
    loading.value = false;
  }
}

function cancelCreateUser() {
  showCreateUserForm.value = false;
  newUserEmail.value = '';
  newUserPassword.value = '';
  newUserFullName.value = '';
  newUserIsAdmin.value = false;
  selectedProjectForNewUser.value = '';
  selectedRoleForNewUser.value = 'viewer';
  error.value = null;
}
</script>

<template>
  <Modal :open="show" @close="emit('close')">
    <div class="w-full max-w-3xl max-h-[90vh] overflow-y-auto">
      <h2 class="text-xl font-semibold text-gray-900 mb-4">User Management</h2>
      
      <div v-if="error" class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-800 text-sm">
        {{ error }}
      </div>
      
      <!-- Create User Button -->
      <div class="mb-4">
        <button
          @click="showCreateUserForm = !showCreateUserForm"
          class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 transition-colors text-sm"
        >
          {{ showCreateUserForm ? 'Cancel' : '+ Create New User' }}
        </button>
      </div>
      
      <!-- Create User Form -->
      <div v-if="showCreateUserForm" class="mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200 space-y-3">
        <h3 class="font-semibold text-gray-900">Create New User</h3>
        
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
            class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <label for="isAdmin" class="text-sm font-medium text-gray-700">Global Admin</label>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Assign to Project (Optional)</label>
          <div class="flex gap-2">
            <select
              v-model="selectedProjectForNewUser"
              class="flex-1 px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">No project assignment</option>
              <option
                v-for="project in projects"
                :key="project.id"
                :value="project.id"
              >
                {{ project.name }}
              </option>
            </select>
            
            <select
              v-if="selectedProjectForNewUser"
              v-model="selectedRoleForNewUser"
              class="px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="viewer">Viewer</option>
              <option value="editor">Editor</option>
              <option value="admin">Admin</option>
            </select>
          </div>
        </div>
        
        <div class="flex gap-2 pt-2">
          <button
            @click="cancelCreateUser"
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
        <h3 class="font-semibold text-gray-900 mb-2">All Users</h3>
        <div
          v-for="user in users"
          :key="user.id"
          class="p-3 bg-gray-50 rounded-lg border border-gray-200"
        >
          <div class="flex items-center justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-2 mb-1">
                <span class="font-medium text-gray-900">
                  {{ user.full_name || user.email }}
                </span>
                <span
                  v-if="user.is_admin"
                  class="px-2 py-0.5 text-xs font-medium rounded bg-purple-100 text-purple-800"
                >
                  Admin
                </span>
              </div>
              <div class="text-xs text-gray-500">
                {{ user.email }}
              </div>
            </div>
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

