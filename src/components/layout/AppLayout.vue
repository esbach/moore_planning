<script setup lang="ts">
import HierarchyTree from '@/components/hierarchy/HierarchyTree.vue';
import OutputActivityPanel from '@/components/hierarchy/OutputActivityPanel.vue';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';
import { ref, computed, watch } from 'vue';
import { useProjectStore } from '@/stores/project';
import { useDataStore } from '@/stores/data';
import { useAuthStore } from '@/stores/auth';
import { updateOutcome } from '@/api/outcomes';
import { isProjectAdmin } from '@/api/projects';
import type { Objective, Output } from '@/types';

const projectStore = useProjectStore();
const dataStore = useDataStore();
const auth = useAuthStore();
const selectedObjective = ref<Objective | null>(null);
const selectedOutput = ref<Output | null>(null);
const outcomeExpanded = ref(false);
const editingOutcome = ref(false);
const editOutcomeTitle = ref('');
const savingOutcome = ref(false);
const isProjectLead = ref(false);

const isAdmin = computed(() => auth.profile?.is_admin === true);
const canEditOutcome = computed(() => isAdmin.value || isProjectLead.value);

// Get first outcome from data store for current project
const outcome = computed(() => {
  if (!projectStore.currentProject) return null;
  const outcomes = dataStore.outcomesByProject(projectStore.currentProject.id);
  return outcomes[0] || null;
});

// Load outcomes when project changes
watch(() => projectStore.currentProject, () => {
  selectedObjective.value = null;
  selectedOutput.value = null;
  outcomeExpanded.value = false;
});

// Reset expanded state when outcome changes
watch(() => outcome.value?.id, () => {
  outcomeExpanded.value = false;
  editingOutcome.value = false;
  editOutcomeTitle.value = '';
});

// Check project admin status when project changes
watch(() => projectStore.currentProject, async (newProject) => {
  if (newProject?.id) {
    try {
      isProjectLead.value = await isProjectAdmin(newProject.id);
    } catch (error) {
      console.error('Failed to check project admin status:', error);
      isProjectLead.value = false;
    }
  } else {
    isProjectLead.value = false;
  }
}, { immediate: true });

function handleObjectiveSelect(objective: Objective | null) {
  selectedObjective.value = objective;
  selectedOutput.value = null;
}

function handleOutputSelect(output: Output | null) {
  selectedOutput.value = output;
}

async function startEditOutcome() {
  if (!outcome.value) return;
  editingOutcome.value = true;
  editOutcomeTitle.value = outcome.value.title;
}

function cancelEditOutcome() {
  editingOutcome.value = false;
  editOutcomeTitle.value = '';
}

async function saveOutcome() {
  if (!outcome.value) return;
  const title = editOutcomeTitle.value.trim();
  if (!title) {
    alert('Title is required');
    return;
  }
  
  savingOutcome.value = true;
  try {
    await updateOutcome(outcome.value.id, {
      title,
    });
    await dataStore.refreshOutcomes();
    editingOutcome.value = false;
  } catch (error) {
    console.error('Failed to update outcome:', error);
    alert('Failed to update outcome. See console for details.');
  } finally {
    savingOutcome.value = false;
  }
}
</script>

<template>
  <div class="h-screen flex">
    <!-- Notion-style Sidebar -->
    <NotionSidebar />
    
    <!-- Main Content Area -->
    <div class="flex-1 flex flex-col overflow-hidden">
      <!-- Outcome Row - Accordion Style -->
      <div v-if="projectStore.currentProject && outcome" class="border-b bg-white flex-shrink-0">
        <!-- Outcome Header Row -->
        <div class="p-4 h-14 flex items-center justify-between">
          <div 
            class="flex items-center gap-2 cursor-pointer flex-1"
            @click="outcomeExpanded = !outcomeExpanded"
          >
            <h3 class="font-semibold text-gray-900">Outcome</h3>
            <svg 
              class="w-4 h-4 text-gray-500 transition-transform flex-shrink-0" 
              :class="{ 'rotate-90': outcomeExpanded }"
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
          
          <!-- Edit Button (Admin or Project Lead only) -->
          <button
            v-if="canEditOutcome && !editingOutcome"
            @click.stop="startEditOutcome"
            class="px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
            title="Edit outcome"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
          </button>
        </div>
        
        <!-- Expanded Content -->
        <div v-if="outcomeExpanded" class="px-4 pb-4 border-t bg-gray-50">
          <!-- Edit Mode -->
          <div v-if="editingOutcome" class="pt-3 space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Title *</label>
              <input
                v-model="editOutcomeTitle"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Outcome title"
                @keydown.enter.prevent="saveOutcome"
              />
            </div>
            <div class="flex gap-2">
              <button
                @click="cancelEditOutcome"
                class="px-4 py-2 text-sm text-gray-700 bg-gray-100 rounded hover:bg-gray-200 transition-colors"
                :disabled="savingOutcome"
              >
                Cancel
              </button>
              <button
                @click="saveOutcome"
                class="px-4 py-2 text-sm bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
                :disabled="savingOutcome || !editOutcomeTitle.trim()"
              >
                {{ savingOutcome ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </div>
          
          <!-- View Mode -->
          <div v-else class="pt-3">
            <p class="text-sm font-medium text-gray-900">{{ outcome.title }}</p>
          </div>
        </div>
      </div>
      
      <!-- No Outcome Message -->
      <div v-else-if="projectStore.currentProject && !outcome" class="border-b bg-white p-4 h-14 flex items-center">
        <p class="text-sm text-gray-500 italic">No outcomes yet. Create an outcome to get started.</p>
      </div>
      
      <!-- No Project Selected Message -->
      <div v-else-if="!projectStore.currentProject" class="flex items-center justify-center h-full text-gray-500">
        <div class="text-center">
          <p class="text-lg mb-2">No project selected</p>
          <p class="text-sm">Select a project from the sidebar to get started</p>
        </div>
      </div>
      
      <!-- Two Column Layout: Objectives (left) | Outputs & Tasks (right) -->
      <div v-if="projectStore.currentProject" class="flex flex-1 overflow-hidden">
        <!-- Left Panel: Objectives -->
        <aside class="w-80 border-r overflow-auto bg-white">
          <HierarchyTree 
            :project-id="projectStore.currentProject.id"
            @objective-selected="handleObjectiveSelect" 
          />
        </aside>
        
        <!-- Right Panel: Outputs & Activities -->
        <main class="flex-1 overflow-auto bg-gray-50">
          <OutputActivityPanel 
            v-if="selectedObjective"
            :objective="selectedObjective"
            @output-selected="handleOutputSelect"
          />
          <div v-else class="flex items-center justify-center h-full text-gray-500">
            <div class="text-center">
              <p class="text-lg mb-2">Select an Objective</p>
              <p class="text-sm">Choose an objective from the left panel to view its outputs and activities</p>
            </div>
          </div>
        </main>
      </div>
    </div>
  </div>
</template>
