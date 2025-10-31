<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { listOutcomes } from '@/api/outcomes';
import { listObjectives, createObjective, deleteObjective, updateObjective } from '@/api/objectives';
import { useAuthStore } from '@/stores/auth';
import { useProjectStore } from '@/stores/project';
import type { Outcome, Objective } from '@/types';

const auth = useAuthStore();
const projectStore = useProjectStore();
const emit = defineEmits<{ (e: 'objective-selected', objective: Objective | null): void }>();

const outcomes = ref<Outcome[]>([]);
const objectivesMap = ref<Record<string, Objective[]>>({});
const selectedObjectiveId = ref<string | null>(null);
const loading = ref(false);
const loadError = ref<string | null>(null);

const isAdmin = computed(() => auth.profile?.is_admin === true);

// UI state
const newObjectiveTitle = ref('');
const showingNewObjective = ref(false);

// Get all objectives from all outcomes as a flat list
const allObjectives = computed(() => {
  const flatList: Objective[] = [];
  Object.values(objectivesMap.value).forEach(objectives => {
    flatList.push(...objectives);
  });
  return flatList;
});

// Get the first outcome for creating new objectives
const firstOutcome = computed(() => outcomes.value[0]);

async function refreshAll() {
  if (!projectStore.currentProject) {
    outcomes.value = [];
    objectivesMap.value = {};
    return;
  }

  loading.value = true;
  loadError.value = null;
  try {
    const ocList = await listOutcomes(projectStore.currentProject.id);
    outcomes.value = ocList;
    // Load objectives concurrently for responsiveness
    const objectivesEntries = await Promise.all(
      ocList.map(async (oc) => {
        const list = await listObjectives(oc.id);
        return [oc.id, list] as const;
      })
    );
    objectivesMap.value = Object.fromEntries(objectivesEntries);
  } catch (e: any) {
    console.error('Failed to load hierarchy', e);
    loadError.value = e?.message || 'Failed to load data';
  } finally {
    loading.value = false;
  }
}

// Reload when project changes
watch(() => projectStore.currentProject, () => {
  selectedObjectiveId.value = null;
  emit('objective-selected', null);
  refreshAll();
});

onMounted(refreshAll);

// Objective management
function startAddObjective() {
  showingNewObjective.value = true;
  newObjectiveTitle.value = '';
}

async function saveNewObjective() {
  if (!firstOutcome.value) {
    alert('No outcome available. Please create an outcome first.');
    return;
  }
  const title = newObjectiveTitle.value.trim();
  if (!title) return;
  await createObjective(firstOutcome.value.id, title);
  showingNewObjective.value = false;
  newObjectiveTitle.value = '';
  await refreshAll();
}

function cancelNewObjective() {
  showingNewObjective.value = false;
  newObjectiveTitle.value = '';
}

async function renameObjective(ob: Objective) {
  const title = window.prompt('Rename objective', ob.title);
  if (!title) return;
  await updateObjective(ob.id, { title });
  await refreshAll();
}

async function editObjectiveNumber(obj: Objective) {
  const shortName = window.prompt('Short name or number (e.g., "A", "Alpha", "1"):', obj.short_name || '');
  if (shortName === null) return; // User cancelled
  
  const indexInput = window.prompt('Index number (for ordering, 0-based):', obj.index !== null ? String(obj.index) : '');
  if (indexInput === null) return; // User cancelled
  
  const index = indexInput.trim() === '' ? null : parseInt(indexInput, 10);
  if (indexInput.trim() !== '' && isNaN(index!)) {
    alert('Invalid index number');
    return;
  }
  
  await updateObjective(obj.id, { 
    short_name: shortName.trim() || null,
    index: index
  });
  await refreshAll();
}

async function removeObjective(ob: Objective) {
  if (!confirm('Delete this objective and its children?')) return;
  await deleteObjective(ob.id);
  if (selectedObjectiveId.value === ob.id) {
    selectedObjectiveId.value = null;
    emit('objective-selected', null);
  }
  await refreshAll();
}

function selectObjective(objective: Objective) {
  selectedObjectiveId.value = objective.id;
  emit('objective-selected', objective);
}
</script>

<template>
  <div class="h-full flex flex-col bg-white">
    <div v-if="loading" class="text-sm text-gray-600 p-4">Loading…</div>
    <div v-else-if="loadError" class="text-sm text-red-600 p-4">{{ loadError }}</div>
    
    <div v-else-if="!projectStore.currentProject" class="flex items-center justify-center h-full text-gray-500">
      <div class="text-center">
        <p class="text-sm">No project selected</p>
      </div>
    </div>
    
    <div v-else class="flex-1 flex flex-col">
      <!-- Header -->
      <div class="p-4 border-b h-14 flex items-center justify-between">
        <h3 class="font-semibold">Objectives</h3>
        <button 
          v-if="isAdmin && firstOutcome"
          @click="startAddObjective()" 
          class="bg-blue-600 text-white w-8 h-8 rounded hover:bg-blue-700 flex items-center justify-center text-lg font-semibold"
          title="Add Objective"
        >
          +
        </button>
      </div>

      <!-- Add Objective Form -->
      <div v-if="isAdmin && showingNewObjective" class="p-4 border-b bg-gray-50">
        <input
          v-model="newObjectiveTitle"
          class="border rounded px-3 py-2 text-sm w-full mb-2"
          placeholder="Objective title"
          @keydown.enter.prevent="saveNewObjective"
        />
        <div class="flex gap-2">
          <button class="text-xs" @click="cancelNewObjective">Cancel</button>
          <button
            class="bg-blue-600 text-white rounded px-3 py-1 text-xs"
            @click="saveNewObjective"
          >
            Save
          </button>
        </div>
      </div>

      <!-- Objectives List -->
      <div class="flex-1 overflow-auto p-4 space-y-2">
        <div
          v-for="obj in allObjectives"
          :key="obj.id"
          @click="selectObjective(obj)"
          class="border rounded-lg p-3 cursor-pointer transition-all hover:shadow-md"
          :class="{ 
            'border-blue-500 bg-blue-50 shadow-md': selectedObjectiveId === obj.id,
            'border-gray-200 bg-white hover:border-gray-300': selectedObjectiveId !== obj.id
          }"
        >
          <div class="space-y-2">
            <!-- Short name on top -->
            <div v-if="obj.short_name || (obj.index !== null && obj.index !== undefined)">
              <span class="text-xs font-semibold text-gray-600 bg-gray-100 px-2 py-0.5 rounded">
                {{ obj.short_name || (obj.index !== null && obj.index !== undefined ? `Obj ${obj.index + 1}` : '') }}
              </span>
            </div>
            
            <!-- Title/Statement -->
            <div class="font-medium text-sm text-gray-900">{{ obj.title }}</div>
            
            <!-- Edit buttons below - right aligned -->
            <div v-if="isAdmin" class="flex gap-1 pt-1 justify-end">
              <button
                @click.stop="editObjectiveNumber(obj)"
                class="text-green-600 hover:text-green-700 text-xs"
                title="Edit number/name"
              >
                🔢
              </button>
              <button
                @click.stop="renameObjective(obj)"
                class="text-blue-600 hover:text-blue-700 text-xs"
                title="Rename"
              >
                ✏️
              </button>
              <button
                @click.stop="removeObjective(obj)"
                class="text-red-600 hover:text-red-700 text-xs"
                title="Delete"
              >
                🗑️
              </button>
            </div>
          </div>
        </div>

        <div v-if="allObjectives.length === 0" class="text-center py-8 text-gray-500 text-sm">
          No objectives yet. {{ isAdmin && firstOutcome ? 'Create an objective to get started.' : (firstOutcome ? '' : 'Create an outcome first.') }}
        </div>
      </div>
    </div>
  </div>
</template>
