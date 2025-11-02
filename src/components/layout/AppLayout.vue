<script setup lang="ts">
import HierarchyTree from '@/components/hierarchy/HierarchyTree.vue';
import OutputActivityPanel from '@/components/hierarchy/OutputActivityPanel.vue';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';
import { ref, computed, watch } from 'vue';
import { useProjectStore } from '@/stores/project';
import { useDataStore } from '@/stores/data';
import type { Objective, Output } from '@/types';

const projectStore = useProjectStore();
const dataStore = useDataStore();
const selectedObjective = ref<Objective | null>(null);
const selectedOutput = ref<Output | null>(null);
const outcomeExpanded = ref(false);

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
});

function handleObjectiveSelect(objective: Objective | null) {
  selectedObjective.value = objective;
  selectedOutput.value = null;
}

function handleOutputSelect(output: Output | null) {
  selectedOutput.value = output;
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
        <div class="p-4 h-14 flex items-center cursor-pointer hover:bg-gray-50 transition-colors" @click="outcomeExpanded = !outcomeExpanded">
          <div class="flex items-center gap-2">
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
        </div>
        
        <!-- Expanded Content -->
        <div v-if="outcomeExpanded" class="px-4 pb-4 border-t bg-gray-50">
          <div class="pt-3">
            <p class="text-sm font-medium text-gray-900 mb-2">{{ outcome.title }}</p>
            <p v-if="outcome.description" class="text-sm text-gray-700 whitespace-pre-wrap">{{ outcome.description }}</p>
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
