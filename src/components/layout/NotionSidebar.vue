<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useProjectStore } from '@/stores/project';
import { useDataStore } from '@/stores/data';
import type { Project } from '@/types';
import AdminPanel from '@/components/admin/AdminPanel.vue';
import ProjectPanel from '@/components/admin/ProjectPanel.vue';
import { isProjectAdmin } from '@/api/projects';

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();
const projectStore = useProjectStore();
const dataStore = useDataStore();

const currentPath = computed(() => route.path);
const isAdmin = computed(() => auth.profile?.is_admin === true);
const showAdminPanel = ref(false);
const showProjectPanel = ref(false);
const isCurrentProjectAdmin = ref(false);
const projectExpanded = ref<Record<string, boolean>>({});

// Get hidden project IDs from localStorage (for admins) - inverted logic
const getHiddenProjectIds = (): string[] => {
  if (!isAdmin.value) return []; // Not an admin, don't filter
  const stored = localStorage.getItem('hidden_project_ids');
  if (!stored) return []; // Default: show all (nothing hidden)
  try {
    const parsed = JSON.parse(stored);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

// Watch for storage changes to update project visibility
const hiddenProjectIds = ref<string[]>(getHiddenProjectIds());

function updateHiddenProjectIds() {
  hiddenProjectIds.value = getHiddenProjectIds();
}

watch(() => dataStore.loaded, () => {
  updateHiddenProjectIds();
});

// Listen for custom event from AdminPanel
onMounted(() => {
  window.addEventListener('projectVisibilityChanged', updateHiddenProjectIds);
  window.addEventListener('storage', updateHiddenProjectIds);
});

// Cleanup listeners (though component doesn't unmount in this app)
// window.removeEventListener('projectVisibilityChanged', updateHiddenProjectIds);

// Get all projects sorted by created_at (most recent first)
const projects = computed(() => {
  let filteredProjects = [...dataStore.projects];
  
  // For admins, filter out hidden projects
  if (isAdmin.value) {
    const hiddenIds = hiddenProjectIds.value;
    // Filter out hidden projects (show all if nothing is hidden)
    if (hiddenIds.length > 0) {
      filteredProjects = filteredProjects.filter(p => !hiddenIds.includes(p.id));
    }
  }
  // Non-admins always see all their accessible projects (already filtered by RLS)
  
  return filteredProjects.sort((a, b) => {
    const dateA = new Date(a.created_at).getTime();
    const dateB = new Date(b.created_at).getTime();
    return dateB - dateA; // Most recent first
  });
});

// Track if we've done initial navigation
const hasNavigatedInitially = ref(false);

// Helper function to select the first visible project
function selectFirstVisibleProject() {
  const visibleProjects = projects.value; // Already filtered and sorted
  const currentProject = projectStore.currentProject;
  
  if (visibleProjects.length > 0) {
    // Check if current project is still visible
    if (currentProject && visibleProjects.some(p => p.id === currentProject.id)) {
      // Current project is visible, keep it
      return;
    }
    // Either no project selected, or current project is hidden - select first visible
    selectProject(visibleProjects[0]);
    // Navigate to outcome table view on initial load if we're at root
    if (!hasNavigatedInitially.value && (currentPath.value === '/' || currentPath.value === '')) {
      router.push('/structure');
      hasNavigatedInitially.value = true;
    }
  } else if (currentProject) {
    // No visible projects but we have a selected one - deselect it
    projectStore.setCurrentProject(null);
  }
}

// Auto-select project when data is loaded and projects are available
watch([() => dataStore.loaded, () => projects.value.length, () => hiddenProjectIds.value], ([loaded, length]) => {
  if (loaded && length > 0) {
    // Always check if we need to select a visible project
    selectFirstVisibleProject();
  }
}, { immediate: true });

// Also watch for when hidden projects change (e.g., admin hides/shows projects)
watch(() => hiddenProjectIds.value, () => {
  if (dataStore.loaded && projects.value.length > 0) {
    selectFirstVisibleProject();
  }
});

// Also ensure we navigate to /structure if we're at root and have a project
watch([() => projectStore.currentProject, () => currentPath.value], ([project, path]) => {
  if (project && (path === '/' || path === '') && !hasNavigatedInitially.value) {
    router.push('/structure');
    hasNavigatedInitially.value = true;
  }
}, { immediate: true });

// Watch for project changes and ensure it stays expanded and is visible
watch(() => projectStore.currentProject, async (newProject) => {
  if (newProject?.id) {
    // Verify the selected project is still visible
    const visibleProjects = projects.value;
    if (!visibleProjects.some(p => p.id === newProject.id)) {
      // Selected project is hidden, select first visible instead
      if (visibleProjects.length > 0) {
        selectProject(visibleProjects[0]);
      } else {
        projectStore.setCurrentProject(null);
      }
      return; // Don't continue with expansion if we changed the project
    }
    
    projectExpanded.value[newProject.id] = true;
    // Check if user is project admin for this project
    await checkProjectAdminStatus(newProject.id);
  } else {
    isCurrentProjectAdmin.value = false;
  }
});

onMounted(() => {
  // Projects are loaded automatically by the data store
  projectStore.loadProjects();
});

function selectProject(project: Project) {
  projectStore.setCurrentProject(project);
  // Auto-expand the selected project and keep it open
  if (project.id) {
    projectExpanded.value[project.id] = true;
  }
}

function toggleProjectExpanded(projectId: string) {
  // Don't allow closing if it's the currently selected project
  if (projectStore.currentProject?.id === projectId && projectExpanded.value[projectId]) {
    // If trying to close the selected project, don't allow it
    // (selected project should always be expanded)
    return;
  }
  projectExpanded.value[projectId] = !projectExpanded.value[projectId];
}

const isProjectExpanded = (projectId: string) => {
  // If it's the currently selected project, always show as expanded
  if (projectStore.currentProject?.id === projectId) {
    return true;
  }
  return projectExpanded.value[projectId] ?? false;
};

const navigationItems = [
  { path: '/structure', label: 'Outcome Table', icon: '📊' },
  { path: '/activities', label: 'Tasks', icon: '📋' },
  { path: '/calendar', label: 'Calendar', icon: '📅' },
  { path: '/progress', label: 'Progress Tracker', icon: '📈' },
];

function navigateTo(path: string) {
  router.push(path);
}

async function checkProjectAdminStatus(projectId: string) {
  try {
    isCurrentProjectAdmin.value = await isProjectAdmin(projectId);
  } catch (error) {
    console.error('Failed to check project admin status:', error);
    isCurrentProjectAdmin.value = false;
  }
}

const userName = computed(() => {
  return auth.profile?.full_name || auth.profile?.email || 'User';
});


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

    <!-- Projects List -->
    <div class="px-2 pb-3 flex-shrink-0">
      <div v-if="dataStore.loading" class="px-2 py-2 text-xs text-gray-500">
        Loading...
      </div>
      
      <div v-else-if="projects.length === 0" class="px-2 py-2 text-xs text-gray-500">
        No projects yet
      </div>
      
      <div v-else class="space-y-1">
        <div 
          v-for="project in projects" 
          :key="project.id" 
          class="rounded transition-colors"
        >
          <!-- Project Header -->
          <div 
            class="px-2 py-1.5 cursor-pointer flex items-center gap-2 text-gray-700 hover:text-gray-900"
            @click="selectProject(project)"
          >
            <svg 
              class="w-3 h-3 text-gray-500 transition-transform flex-shrink-0"
              :class="{ 'rotate-90': isProjectExpanded(project.id) }"
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
              @click.stop="toggleProjectExpanded(project.id)"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            <span class="text-sm font-medium truncate flex-1">
              {{ project.name }}
            </span>
          </div>
          
          <!-- Nested Navigation (only show when project is selected and expanded) -->
          <div 
            v-if="projectStore.currentProject?.id === project.id && isProjectExpanded(project.id)"
            class="ml-6 space-y-0.5 pb-1"
          >
            <button
              v-for="item in navigationItems"
              :key="item.path"
              @click="navigateTo(item.path)"
              class="w-full flex items-center gap-2.5 px-2 py-1.5 rounded text-sm transition-colors"
              :class="currentPath === item.path 
                ? 'bg-gray-200 text-gray-900' 
                : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'"
            >
              <span class="text-base leading-none">{{ item.icon }}</span>
              <span class="font-normal text-xs">{{ item.label }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Project Panel (Project Lead only, when project selected - NOT for global admins) -->
    <div v-if="projectStore.currentProject && isCurrentProjectAdmin && !isAdmin" class="px-4 pb-4 flex-shrink-0">
      <button
        @click="showProjectPanel = true"
        class="w-full flex items-center gap-2.5 px-3 py-2 rounded text-sm text-gray-700 hover:bg-gray-200 hover:text-gray-900 transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
        </svg>
        <span class="font-normal">Manage Project</span>
      </button>
    </div>

    <!-- Admin Panel (Global Admin only) -->
    <div v-if="isAdmin" class="px-4 pb-4 flex-shrink-0">
      <button
        @click="showAdminPanel = true"
        class="w-full flex items-center gap-2.5 px-3 py-2 rounded text-sm text-gray-700 hover:bg-gray-200 hover:text-gray-900 transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
        <span class="font-normal">Admin Panel</span>
      </button>
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

    <!-- Admin Panel Modal -->
    <AdminPanel
      :show="showAdminPanel"
      @close="showAdminPanel = false"
    />

    <!-- Project Panel Modal -->
    <ProjectPanel
      :show="showProjectPanel"
      :project-id="projectStore.currentProject?.id || null"
      @close="showProjectPanel = false"
    />
  </div>
</template>

