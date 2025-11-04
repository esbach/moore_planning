<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { createOutput, deleteOutput, updateOutput } from '@/api/outputs';
import { createActivity, deleteActivity, updateActivity } from '@/api/activities';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import type { Objective, Output, Activity } from '@/types';
import ActivityForm from './ActivityForm.vue';

const auth = useAuthStore();
const dataStore = useDataStore();
const router = useRouter();
const props = defineProps<{ objective: Objective }>();
const emit = defineEmits<{ (e: 'output-selected', output: Output | null): void }>();

const isAdmin = computed(() => auth.profile?.is_admin === true);

const selectedOutputId = ref<string | null>(null);

// Form states
const showNewOutput = ref(false);
const newOutputTitle = ref('');
const showActivityForm = ref(false);
const currentActivityInitial = ref<Partial<Activity> | undefined>();

// Get outputs from data store
const outputs = computed(() => dataStore.outputsByObjective(props.objective.id));

// Get activities map from data store
const activitiesMap = computed(() => {
  const map: Record<string, Activity[]> = {};
  outputs.value.forEach(output => {
    map[output.id] = dataStore.activitiesByOutput(output.id);
  });
  return map;
});

const selectedOutput = computed(() => outputs.value.find(o => o.id === selectedOutputId.value) || null);
const selectedActivities = computed(() => selectedOutputId.value ? activitiesMap.value[selectedOutputId.value] || [] : []);

// Profiles from data store
const profiles = computed(() => dataStore.profiles);

async function refreshData() {
  try {
    await Promise.all([
      dataStore.refreshOutputs(),
      dataStore.refreshActivities(),
    ]);
  } catch (e: any) {
    console.error('Failed to refresh outputs/activities:', e);
  }
}

// Clear selection when objective changes
watch(() => props.objective.id, () => {
  selectedOutputId.value = null;
  emit('output-selected', null);
});

// Output management
function selectOutput(output: Output) {
  selectedOutputId.value = output.id;
  emit('output-selected', output);
}

function startAddOutput() {
  showNewOutput.value = true;
  newOutputTitle.value = '';
}

async function saveNewOutput() {
  const title = newOutputTitle.value.trim();
  if (!title) return;
  try {
    await createOutput(props.objective.id, title);
    showNewOutput.value = false;
    newOutputTitle.value = '';
    await refreshData();
  } catch (e) {
    console.error(e);
    alert('Failed to create output. See console for details.');
  }
}

function cancelNewOutput() {
  showNewOutput.value = false;
  newOutputTitle.value = '';
}

async function renameOutput(output: Output) {
  const title = window.prompt('Rename output', output.title);
  if (!title) return;
  await updateOutput(output.id, { title });
  await refreshData();
}

async function editOutputNumber(output: Output) {
  const shortName = window.prompt('Short name or number (e.g., "A", "Alpha", "1"):', output.short_name || '');
  if (shortName === null) return; // User cancelled
  
  const indexInput = window.prompt('Index number (for ordering, 0-based):', output.index !== null ? String(output.index) : '');
  if (indexInput === null) return; // User cancelled
  
  const index = indexInput.trim() === '' ? null : parseInt(indexInput, 10);
  if (indexInput.trim() !== '' && isNaN(index!)) {
    alert('Invalid index number');
    return;
  }
  
  await updateOutput(output.id, { 
    short_name: shortName.trim() || null,
    index: index
  });
  await refreshData();
}

async function deleteOutputById(output: Output) {
  if (!confirm('Delete this output and all its activities?')) return;
  await deleteOutput(output.id);
  if (selectedOutputId.value === output.id) {
    selectedOutputId.value = null;
    emit('output-selected', null);
  }
  await refreshData();
}

// Activity management
function newActivity(outputId: string) {
  selectedOutputId.value = outputId;
  currentActivityInitial.value = undefined;
  showActivityForm.value = true;
}

async function saveActivity(partial: Partial<Activity>) {
  if (!selectedOutputId.value) return;
  try {
    await createActivity({
      output_id: selectedOutputId.value,
      title: partial.title!,
      description: partial.description ?? null,
      assignee_id: partial.assignee_id ?? null,
      start_date: partial.start_date ?? null,
      end_date: partial.end_date ?? null,
      status: (partial.status as any) ?? 'not_started',
      source_links: partial.source_links ?? [],
    } as any);
    await dataStore.refreshActivities();
    showActivityForm.value = false;
  } catch (e) {
    console.error('Failed to create task:', e);
    alert('Failed to create task. See console for details.');
  }
}

async function deleteActivityById(activity: Activity) {
  if (!confirm('Delete this task?')) return;
  await deleteActivity(activity.id);
  await dataStore.refreshActivities();
}

function getProfileName(profileId: string | null) {
  if (!profileId) return 'Unassigned';
  const profile = dataStore.profileById(profileId);
  return profile?.full_name || profile?.email || 'Unknown';
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString();
}

function getStatusColor(status: string) {
  const colors = {
    'not_started': 'bg-gray-100 text-gray-700 border border-gray-200',
    'started': 'bg-blue-50 text-blue-700 border border-blue-200',
    'in_progress': 'bg-blue-100 text-blue-800 border border-blue-300',
    'review': 'bg-yellow-50 text-yellow-800 border border-yellow-200',
    'complete': 'bg-green-50 text-green-700 border border-green-200'
  };
  return colors[status as keyof typeof colors] || 'bg-gray-100 text-gray-700 border border-gray-200';
}

function formatStatus(status: string) {
  const statusMap: Record<string, string> = {
    'not_started': 'Not Started',
    'started': 'Started',
    'in_progress': 'In Progress',
    'review': 'Review',
    'complete': 'Complete'
  };
  return statusMap[status] || status.replace('_', ' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

function openTaskInTasksPage(activity: Activity) {
  router.push({ path: '/activities', query: { activityId: activity.id } });
}
</script>

<template>
  <div class="h-full flex flex-col bg-gray-50">
    <!-- Two Column Layout: Outputs (left) | Activities (right) -->
    <div class="flex flex-1 overflow-hidden">
      <!-- Left Column: Outputs List -->
      <div class="w-80 border-r bg-white flex flex-col">
        <div class="p-4 border-b h-14 flex items-center justify-between">
          <h3 class="font-semibold">Outputs</h3>
          <button 
            v-if="isAdmin"
            @click="startAddOutput" 
            class="bg-blue-600 text-white w-8 h-8 rounded hover:bg-blue-700 flex items-center justify-center text-lg font-semibold"
          >
            +
          </button>
        </div>

        <!-- Add Output Form -->
        <div v-if="showNewOutput" class="p-4 border-b bg-gray-50">
          <input 
            v-model="newOutputTitle" 
            class="border rounded px-3 py-2 text-sm w-full mb-2" 
            placeholder="Output title"
            @keydown.enter.prevent="saveNewOutput"
          />
          <div class="flex gap-2">
            <button class="text-xs" @click="cancelNewOutput">Cancel</button>
            <button class="bg-blue-600 text-white rounded px-3 py-1 text-xs" @click="saveNewOutput">Save</button>
          </div>
        </div>

        <div class="flex-1 overflow-auto p-4">
          <div v-if="dataStore.loading" class="text-sm text-gray-600">Loading...</div>
          <div v-else-if="dataStore.error" class="text-sm text-red-600">{{ dataStore.error }}</div>
          
          <div v-else class="space-y-2">
            <div
              v-for="output in outputs"
              :key="output.id"
              @click="selectOutput(output)"
              class="border rounded-lg p-3 cursor-pointer transition-all"
              :class="{ 
                'border-blue-500 bg-blue-50 shadow-md': selectedOutputId === output.id,
                'border-gray-200 bg-white hover:border-gray-300 hover:shadow-sm': selectedOutputId !== output.id
              }"
            >
              <div class="space-y-2">
                <!-- Short name on top -->
                <div v-if="output.short_name || (output.index !== null && output.index !== undefined)">
                  <span class="text-xs font-semibold text-gray-600 bg-gray-100 px-2 py-0.5 rounded">
                    {{ output.short_name || (output.index !== null && output.index !== undefined ? `Out ${output.index + 1}` : '') }}
                  </span>
                </div>
                
                <!-- Output title -->
                <div class="font-medium text-sm text-gray-900">{{ output.title }}</div>
                
                <!-- Task count below -->
                <div class="text-xs text-gray-600">
                  {{ activitiesMap[output.id]?.length || 0 }} tasks
                </div>
                
                <!-- Edit buttons below - right aligned -->
                <div v-if="isAdmin" class="flex gap-1 pt-1 justify-end">
                  <button
                    @click.stop="editOutputNumber(output)"
                    class="text-green-600 hover:text-green-700 text-xs"
                    title="Edit number/name"
                  >
                    🔢
                  </button>
                  <button
                    @click.stop="renameOutput(output)"
                    class="text-blue-600 hover:text-blue-700 text-xs"
                    title="Rename"
                  >
                    ✏️
                  </button>
                  <button
                    @click.stop="deleteOutputById(output)"
                    class="text-red-600 hover:text-red-700 text-xs"
                    title="Delete"
                  >
                    🗑️
                  </button>
                </div>
              </div>
            </div>

            <div v-if="outputs.length === 0" class="text-center py-8 text-gray-500 text-sm">
              No outputs yet
            </div>
          </div>
        </div>
      </div>

      <!-- Right Column: Activities List -->
      <div class="flex-1 flex flex-col bg-white">
        <div class="p-4 border-b h-14 flex items-center justify-between">
          <h3 class="font-semibold">
            Tasks
            <span v-if="selectedOutput" class="text-sm text-gray-600 ml-2">{{ selectedActivities.length }}</span>
          </h3>
          <button
            v-if="selectedOutput"
            @click="newActivity(selectedOutput.id)"
            class="bg-green-600 text-white w-8 h-8 rounded hover:bg-green-700 flex items-center justify-center text-lg font-semibold"
          >
            +
          </button>
        </div>

        <div class="flex-1 overflow-auto p-4">
          <div v-if="!selectedOutput" class="flex items-center justify-center h-full text-gray-400">
            <div class="text-center">
              <p class="mb-2">Select an output</p>
              <p class="text-sm">Choose an output from the left to view its tasks</p>
            </div>
          </div>

          <div v-else-if="selectedActivities.length === 0" class="flex items-center justify-center h-full text-gray-400">
            <div class="text-center">
              <p class="mb-2">No tasks yet</p>
              <button
                @click="newActivity(selectedOutput.id)"
                class="text-green-700 hover:text-green-800 text-sm"
              >
                + Add first task
              </button>
            </div>
          </div>

          <div v-else class="space-y-1">
            <div
              v-for="activity in selectedActivities"
              :key="activity.id"
              @click="openTaskInTasksPage(activity)"
              class="group flex items-center justify-between px-3 py-2 border-b border-gray-100 hover:bg-gray-50 transition-colors cursor-pointer"
            >
              <div class="flex items-center gap-3 flex-1 min-w-0">
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-sm text-gray-900 truncate">{{ activity.title }}</div>
                </div>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <span 
                    class="px-2.5 py-0.5 rounded-full text-xs font-medium inline-flex items-center whitespace-nowrap"
                    :class="getStatusColor(activity.status)"
                  >
                    {{ formatStatus(activity.status) }}
                  </span>
                </div>
              </div>
              <button
                @click.stop="deleteActivityById(activity)"
                class="text-red-600 hover:text-red-700 text-xs ml-2 p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                title="Delete"
              >
                🗑️
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Activity Form Modal -->
    <ActivityForm
      v-model="showActivityForm"
      :output-id="selectedOutputId || ''"
      :initial="currentActivityInitial"
      @save="saveActivity"
    />
  </div>
</template>
