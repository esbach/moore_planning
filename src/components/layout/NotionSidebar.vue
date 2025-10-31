<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useProjectStore } from '@/stores/project';
import { createProject } from '@/api/projects';

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();
const projectStore = useProjectStore();

const currentPath = computed(() => route.path);
const isAdmin = computed(() => auth.profile?.is_admin === true);
const showNewProjectForm = ref(false);
const newProjectName = ref('');
const newProjectDescription = ref('');

const navigationItems = [
  { path: '/structure', label: 'Outcome Table', icon: '📊' },
  { path: '/activities', label: 'Tasks', icon: '📋' },
  { path: '/calendar', label: 'Calendar', icon: '📅' },
  { path: '/progress', label: 'Progress Tracker', icon: '📈' },
];

function navigateTo(path: string) {
  router.push(path);
}

const userName = computed(() => {
  return auth.profile?.full_name || auth.profile?.email || 'User';
});

onMounted(async () => {
  await projectStore.loadProjects();
});

async function handleCreateProject() {
  const name = newProjectName.value.trim();
  if (!name) return;
  
  try {
    await createProject(name, newProjectDescription.value.trim() || null);
    await projectStore.loadProjects();
    newProjectName.value = '';
    newProjectDescription.value = '';
    showNewProjectForm.value = false;
  } catch (error) {
    console.error('Failed to create project:', error);
    alert('Failed to create project. See console for details.');
  }
}

function cancelNewProject() {
  showNewProjectForm.value = false;
  newProjectName.value = '';
  newProjectDescription.value = '';
}

async function handleSignOut() {
  try {
    await auth.signOut();
    // Navigate to root to show login page
    router.push('/');
  } catch (error) {
    console.error('Sign out error:', error);
    // Still try to navigate even if there's an error
    router.push('/');
  }
}
</script>

<template>
  <div class="h-screen w-64 bg-gray-100 flex flex-col overflow-hidden">
    <!-- User Name Section -->
    <div class="px-4 pt-6 pb-8 flex-shrink-0">
      <div class="flex items-center gap-2.5">
        <div class="w-8 h-8 rounded bg-gray-400 flex items-center justify-center text-white text-sm font-semibold flex-shrink-0">
          {{ userName.charAt(0).toUpperCase() }}
        </div>
        <span class="text-sm font-medium text-gray-900 truncate">{{ userName }}</span>
      </div>
    </div>

    <!-- Projects Section -->
    <div class="px-4 pb-2 flex-shrink-0">
      <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wider">Projects</h3>
    </div>

    <!-- Project Name Section -->
    <div class="px-4 pb-4 flex-shrink-0">
      <span class="text-sm font-medium text-gray-800 truncate">
        {{ projectStore.currentProject?.name || 'No Project Selected' }}
      </span>
    </div>

    <!-- Project-related Navigation (Indented) -->
    <div class="px-4 pb-4 flex-shrink-0">
      <div class="ml-7 space-y-1">
        <button
          v-for="item in navigationItems"
          :key="item.path"
          @click="navigateTo(item.path)"
          class="w-full flex items-center gap-2.5 px-3 py-2 rounded text-sm transition-colors"
          :class="currentPath === item.path 
            ? 'bg-gray-200 text-gray-900' 
            : 'text-gray-700 hover:bg-gray-200 hover:text-gray-900'"
        >
          <span class="text-base leading-none">{{ item.icon }}</span>
          <span class="font-normal">{{ item.label }}</span>
        </button>
      </div>
    </div>

    <!-- New Project Button (Admin only) -->
    <div v-if="isAdmin" class="px-4 pb-4 flex-shrink-0">
      <button
        @click="showNewProjectForm = !showNewProjectForm"
        class="w-full flex items-center gap-2.5 px-3 py-2 rounded text-sm text-gray-700 hover:bg-gray-200 hover:text-gray-900 transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        <span class="font-normal">New Project</span>
      </button>
      
      <!-- New Project Form -->
      <div v-if="showNewProjectForm" class="mt-3 p-3 bg-white rounded-lg border border-gray-300 shadow-sm space-y-2">
        <input
          v-model="newProjectName"
          class="w-full px-3 py-2 bg-white text-gray-900 rounded text-sm border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          placeholder="Project name"
          @keydown.enter.prevent="handleCreateProject"
        />
        <textarea
          v-model="newProjectDescription"
          class="w-full px-3 py-2 bg-white text-gray-900 rounded text-sm border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
          placeholder="Description (optional)"
          rows="2"
        />
        <div class="flex gap-2 pt-1">
          <button
            class="flex-1 px-3 py-1.5 text-xs text-gray-700 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
            @click="cancelNewProject"
          >
            Cancel
          </button>
          <button
            class="flex-1 px-3 py-1.5 bg-blue-600 text-white rounded text-xs hover:bg-blue-700 transition-colors"
            @click="handleCreateProject"
          >
            Create
          </button>
        </div>
      </div>
    </div>

    <!-- Spacer -->
    <div class="flex-1"></div>

    <!-- Sign Out Button (Bottom) -->
    <div class="px-4 pb-6 flex-shrink-0">
      <button
        @click="handleSignOut"
        class="w-full flex items-center gap-2.5 px-3 py-2 rounded text-sm text-gray-700 hover:bg-gray-200 hover:text-gray-900 transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
        </svg>
        <span class="font-normal">Sign out</span>
      </button>
    </div>
  </div>
</template>

