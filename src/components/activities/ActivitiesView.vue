<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { updateActivity } from '@/api/activities';
import { useAuthStore } from '@/stores/auth';
import { useDataStore } from '@/stores/data';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';
import type { Activity, ActivityStatus, Output, Objective } from '@/types';

const auth = useAuthStore();
const dataStore = useDataStore();
const route = useRoute();

interface ActivityWithContext extends Activity {
  objectiveNumber: string | null;
  objectiveTitle: string | null;
  outputNumber: string | null;
  outputTitle: string | null;
}

const filteredActivities = ref<ActivityWithContext[]>([]);
const statusFilter = ref<string | null>(null);
const selectedActivity = ref<ActivityWithContext | null>(null);
const selectedUserId = ref<string | null>(null); // null = my tasks, '' = all, specific id = that user

// Sorting state
type SortColumn = 'objective' | 'task' | 'assignee' | 'status' | 'startDate' | 'endDate' | 'due' | null;
const sortColumn = ref<SortColumn>(null);
const sortDirection = ref<'asc' | 'desc'>('asc');

// Inline editing state
const isEditing = ref(false);
const editStatus = ref<ActivityStatus>('not_started');
const editAssigneeId = ref<string | null>(null);
const editStartDate = ref<string | null>(null);
const editEndDate = ref<string | null>(null);
const editDescription = ref('');
const editNotes = ref('');
const saving = ref(false);

// Accordion states
const objectiveExpanded = ref(false); // Default closed
const outputExpanded = ref(true); // Default open

// Get activities with context from data store
const activitiesWithContext = computed(() => {
  // Build maps for quick lookup
  const outputMap = new Map<string, Output>(dataStore.outputs.map(o => [o.id, o]));
  const objectiveMap = new Map<string, Objective>(dataStore.objectives.map(o => [o.id, o]));
  
  // Enrich activities with context
  return dataStore.activities.map(activity => {
    const output = outputMap.get(activity.output_id);
    const objective = output ? objectiveMap.get(output.objective_id) : null;
    
    return {
      ...activity,
      objectiveNumber: objective 
        ? (objective.short_name || (objective.index !== null && objective.index !== undefined ? `Obj ${objective.index + 1}` : null))
        : null,
      objectiveTitle: objective?.title || null,
      outputNumber: output 
        ? (output.short_name || (output.index !== null && output.index !== undefined ? `Out ${output.index + 1}` : null))
        : null,
      outputTitle: output?.title || null,
    };
  });
});

// Profiles from data store
const profiles = computed(() => dataStore.profiles);

// Loading state from data store
const loading = computed(() => dataStore.loading);

function loadData() {
  // Data is already loaded in store, just apply filters
  applyFilters();
}

function selectUser(userId: string | null) {
  selectedUserId.value = userId;
  applyFilters();
}

function applyFilters() {
  let filtered = activitiesWithContext.value;
  
  // Filter by assignee
  if (selectedUserId.value === null) {
    // Show only my tasks (including unassigned tasks if I created them, or all unassigned)
    filtered = filtered.filter(a => 
      a.assignee_id === auth.profile?.id || 
      a.assignee_id === null // Show unassigned tasks in "My Tasks" too
    );
  } else if (selectedUserId.value !== '') {
    // Show specific user's tasks
    filtered = filtered.filter(a => a.assignee_id === selectedUserId.value);
  }
  // else selectedUserId.value === '' means show all
  
  if (statusFilter.value) {
    filtered = filtered.filter(a => a.status === statusFilter.value);
  }
  
  // Apply sorting
  if (sortColumn.value) {
    filtered = [...filtered].sort((a, b) => {
      let aValue: any;
      let bValue: any;
      
      switch (sortColumn.value) {
        case 'objective':
          aValue = a.objectiveNumber || a.objectiveTitle || '';
          bValue = b.objectiveNumber || b.objectiveTitle || '';
          break;
        case 'task':
          aValue = a.title.toLowerCase();
          bValue = b.title.toLowerCase();
          break;
        case 'assignee':
          aValue = getProfileName(a.assignee_id).toLowerCase();
          bValue = getProfileName(b.assignee_id).toLowerCase();
          break;
        case 'status':
          // Use status order for proper sorting
          const statusOrder: Record<string, number> = {
            'not_started': 0,
            'started': 1,
            'in_progress': 2,
            'review': 3,
            'complete': 4
          };
          aValue = statusOrder[a.status] ?? 999;
          bValue = statusOrder[b.status] ?? 999;
          break;
        case 'startDate':
          if (a.start_date) {
            const [ay, am, ad] = a.start_date.split('-').map(Number);
            aValue = new Date(ay, am - 1, ad).getTime();
          } else {
            aValue = Infinity;
          }
          if (b.start_date) {
            const [by, bm, bd] = b.start_date.split('-').map(Number);
            bValue = new Date(by, bm - 1, bd).getTime();
          } else {
            bValue = Infinity;
          }
          break;
        case 'endDate':
          if (a.end_date) {
            const [ay, am, ad] = a.end_date.split('-').map(Number);
            aValue = new Date(ay, am - 1, ad).getTime();
          } else {
            aValue = Infinity;
          }
          if (b.end_date) {
            const [by, bm, bd] = b.end_date.split('-').map(Number);
            bValue = new Date(by, bm - 1, bd).getTime();
          } else {
            bValue = Infinity;
          }
          break;
        case 'due':
          const aDays = getDaysUntilDue(a.end_date);
          const bDays = getDaysUntilDue(b.end_date);
          aValue = aDays !== null ? aDays : Infinity;
          bValue = bDays !== null ? bDays : Infinity;
          break;
        default:
          return 0;
      }
      
      if (aValue < bValue) return sortDirection.value === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortDirection.value === 'asc' ? 1 : -1;
      return 0;
    });
  }
  
  filteredActivities.value = filtered;
}

function handleSort(column: SortColumn) {
  if (sortColumn.value === column) {
    // Toggle direction if clicking the same column
    sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc';
  } else {
    // Set new column and default to ascending
    sortColumn.value = column;
    sortDirection.value = 'asc';
  }
  applyFilters();
}

function getSortIcon(column: SortColumn) {
  if (sortColumn.value !== column) {
    return '⇅'; // Neutral sort icon
  }
  return sortDirection.value === 'asc' ? '▲' : '▼';
}

function getSortClass(column: SortColumn) {
  if (sortColumn.value === column) {
    return 'text-gray-900';
  }
  return 'text-gray-400';
}


function getDaysUntilDue(endDate: string | null): number | null {
  if (!endDate) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  // Parse date string as local date to avoid timezone issues
  const [year, month, day] = endDate.split('-').map(Number);
  const due = new Date(year, month - 1, day);
  due.setHours(0, 0, 0, 0);
  const diffTime = due.getTime() - today.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return diffDays;
}

function formatDaysUntilDue(endDate: string | null): string {
  const days = getDaysUntilDue(endDate);
  if (days === null) return '-';
  if (days < 0) return `-${Math.abs(days)}`;
  return `${days}`;
}

// Initialize on mount
onMounted(() => {
  selectedUserId.value = null; // My tasks by default
  loadData();
  
  // Check for activityId in query params to open details panel
  const activityId = route.query.activityId as string | undefined;
  if (activityId) {
    // Find the activity in the loaded activities
    const activity = activitiesWithContext.value.find(a => a.id === activityId);
    if (activity) {
      selectedActivity.value = activity;
    }
  }
});

watch([statusFilter, selectedUserId], applyFilters);

// Reset editing when activity changes
watch(() => selectedActivity.value?.id, () => {
  isEditing.value = false;
  editNotes.value = '';
  objectiveExpanded.value = false; // Reset to closed
  outputExpanded.value = true; // Reset to open
});

// Watch for route query changes to open activity details
watch(() => route.query.activityId, (activityId) => {
  if (activityId && typeof activityId === 'string') {
    // Find the activity in all activities (not just filtered)
    const activity = activitiesWithContext.value.find(a => a.id === activityId);
    if (activity) {
      selectedActivity.value = activity;
      // Scroll to the activity in the list if it's visible in filtered results
      const filteredIndex = filteredActivities.value.findIndex(a => a.id === activityId);
      if (filteredIndex >= 0) {
        // Activity is visible in current filter, will be highlighted by :class binding
      }
    }
  }
}, { immediate: false });


function getProfileName(profileId: string | null) {
  if (!profileId) return 'Unassigned';
  const profile = dataStore.profileById(profileId);
  return profile?.full_name || profile?.email || 'Unknown';
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '-';
  // Parse date string as local date to avoid timezone issues
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  const monthStr = String(date.getMonth() + 1).padStart(2, '0');
  const dayStr = String(date.getDate()).padStart(2, '0');
  const yearStr = date.getFullYear();
  return `${monthStr}/${dayStr}/${yearStr}`;
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

function selectActivity(activity: ActivityWithContext) {
  selectedActivity.value = activity;
}

function closeDetailPanel() {
  selectedActivity.value = null;
  isEditing.value = false;
}

function startEditing() {
  if (!selectedActivity.value) return;
  isEditing.value = true;
  editStatus.value = selectedActivity.value.status;
  editAssigneeId.value = selectedActivity.value.assignee_id;
  editStartDate.value = selectedActivity.value.start_date || null;
  editEndDate.value = selectedActivity.value.end_date || null;
  editDescription.value = selectedActivity.value.description || '';
  editNotes.value = '';
}

function cancelEditing() {
  isEditing.value = false;
  editNotes.value = '';
}

async function saveChanges() {
  if (!selectedActivity.value || saving.value) return;
  
  saving.value = true;
  try {
    const updates: Partial<Activity> = {
      status: editStatus.value,
      assignee_id: editAssigneeId.value,
      start_date: editStartDate.value || null,
      end_date: editEndDate.value || null,
      description: editDescription.value.trim() || null,
    };
    
    await updateActivity(selectedActivity.value.id, updates);
    
    // If there are notes, create a progress update with notes
    if (editNotes.value.trim()) {
      const { createProgressUpdate } = await import('@/api/progressUpdates');
      await createProgressUpdate(
        selectedActivity.value.id,
        auth.profile?.id || '',
        0,
        editStatus.value,
        editNotes.value.trim()
      );
    }
    
    // Refresh activities from store
    await dataStore.refreshActivities();
    // Refresh the selected activity
    const updated = activitiesWithContext.value.find(a => a.id === selectedActivity.value?.id);
    if (updated) {
      selectedActivity.value = updated;
    }
    isEditing.value = false;
    editNotes.value = '';
  } catch (e) {
    console.error('Failed to save changes:', e);
    alert('Failed to save changes. See console for details.');
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="h-screen flex">
    <!-- Notion-style Sidebar -->
    <NotionSidebar />
    
    <div class="flex-1 flex flex-col bg-white overflow-hidden">
      <!-- Header - Full width like Calendar -->
      <div class="p-4 border-b flex-shrink-0">
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-bold">Tasks</h2>
          <!-- Filters -->
          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2">
              <label class="text-sm font-medium text-gray-700">User:</label>
              <select
                :value="selectedUserId === null ? 'me' : (selectedUserId === '' ? 'all' : selectedUserId)"
                @change="(e) => {
                  const val = (e.target as HTMLSelectElement).value;
                  if (val === 'me') selectUser(null);
                  else if (val === 'all') selectUser('');
                  else selectUser(val);
                }"
                class="border border-gray-300 rounded-md px-3 py-1.5 text-sm bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="me">My Tasks</option>
                <option value="all">All Tasks</option>
                <option v-for="profile in profiles" :key="profile.id" :value="profile.id">
                  {{ profile.full_name || profile.email || profile.id }}
                </option>
              </select>
            </div>
            <div class="flex items-center gap-2">
              <label class="text-sm font-medium text-gray-700">Status:</label>
              <select
                v-model="statusFilter"
                class="border border-gray-300 rounded-md px-3 py-1.5 text-sm bg-white text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option :value="null">All</option>
                <option value="not_started">Not Started</option>
                <option value="started">Started</option>
                <option value="in_progress">In Progress</option>
                <option value="review">Review</option>
                <option value="complete">Complete</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Tasks Table and Details -->
      <div class="flex-1 relative overflow-hidden" style="min-height: 0;">
        <!-- Tasks Table -->
        <div class="absolute inset-0 overflow-auto">
          <div v-if="dataStore.loading" class="flex items-center justify-center h-full text-gray-600">Loading...</div>
          <div v-else-if="filteredActivities.length === 0" class="flex flex-col items-center justify-center h-full text-gray-400">
            <p class="text-lg mb-2">No tasks found</p>
            <p class="text-sm">Try adjusting your filters</p>
          </div>
          <div v-else class="w-full min-w-0">
            <!-- Table Header -->
            <div class="sticky top-0 bg-white border-b border-gray-200 z-10">
              <div class="grid gap-3 px-6 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wider min-w-0"
                   style="grid-template-columns: 2fr 2.7fr 1.5fr 1.2fr 1fr 1fr 0.6fr;">
                <div 
                  class="flex items-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('objective')"
                  @click="handleSort('objective')"
                >
                  <span>Objective</span>
                  <span class="text-xs">{{ getSortIcon('objective') }}</span>
                </div>
                <div 
                  class="flex items-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('task')"
                  @click="handleSort('task')"
                >
                  <span>Task</span>
                  <span class="text-xs">{{ getSortIcon('task') }}</span>
                </div>
                <div 
                  class="flex items-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('assignee')"
                  @click="handleSort('assignee')"
                >
                  <span>Assignee</span>
                  <span class="text-xs">{{ getSortIcon('assignee') }}</span>
                </div>
                <div 
                  class="flex items-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('status')"
                  @click="handleSort('status')"
                >
                  <span>Status</span>
                  <span class="text-xs">{{ getSortIcon('status') }}</span>
                </div>
                <div 
                  class="text-center flex items-center justify-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('startDate')"
                  @click="handleSort('startDate')"
                >
                  <span>Start Date</span>
                  <span class="text-xs">{{ getSortIcon('startDate') }}</span>
                </div>
                <div 
                  class="text-center flex items-center justify-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('endDate')"
                  @click="handleSort('endDate')"
                >
                  <span>End Date</span>
                  <span class="text-xs">{{ getSortIcon('endDate') }}</span>
                </div>
                <div 
                  class="text-center flex items-center justify-center gap-1 cursor-pointer hover:text-gray-700 select-none transition-colors"
                  :class="getSortClass('due')"
                  @click="handleSort('due')"
                >
                  <span>Due</span>
                  <span class="text-xs">{{ getSortIcon('due') }}</span>
                </div>
              </div>
            </div>
            
            <!-- Table Rows -->
            <div class="divide-y divide-gray-100 min-w-0">
              <div
                v-for="activity in filteredActivities"
                :key="activity.id"
                @click="selectActivity(activity)"
                class="grid gap-3 px-6 py-3 hover:bg-gray-50 cursor-pointer transition-colors border-b border-gray-50 min-w-0"
                style="grid-template-columns: 2fr 2.7fr 1.5fr 1.2fr 1fr 1fr 0.6fr;"
                :class="selectedActivity?.id === activity.id ? 'bg-blue-50' : 'bg-white'"
              >
                <div class="flex items-center min-w-0">
                  <span class="text-sm font-medium text-gray-700 truncate" :title="activity.objectiveNumber || '-'">
                    {{ activity.objectiveNumber || '-' }}
                  </span>
                </div>
                <div class="flex items-center min-w-0">
                  <span class="text-sm font-medium text-gray-900 truncate" :title="activity.title">
                    {{ activity.title }}
                  </span>
                </div>
                <div class="flex items-center min-w-0">
                  <span class="text-sm text-gray-600 truncate" :title="getProfileName(activity.assignee_id)">
                    {{ getProfileName(activity.assignee_id) }}
                  </span>
                </div>
                <div class="flex items-center">
                  <span 
                    class="px-2.5 py-0.5 rounded-full text-xs font-medium inline-flex items-center whitespace-nowrap"
                    :class="getStatusColor(activity.status)"
                  >
                    {{ formatStatus(activity.status) }}
                  </span>
                </div>
                <div class="flex items-center justify-center">
                  <span class="text-sm text-gray-600 whitespace-nowrap">{{ formatDate(activity.start_date) }}</span>
                </div>
                <div class="flex items-center justify-center">
                  <span class="text-sm text-gray-600 whitespace-nowrap">{{ formatDate(activity.end_date) }}</span>
                </div>
                <div class="flex items-center justify-center">
                  <span 
                    v-if="activity.end_date"
                    class="px-2.5 py-0.5 rounded text-xs font-medium whitespace-nowrap"
                    :class="getDaysUntilDue(activity.end_date)! < 0 
                      ? 'text-red-600 bg-red-50' 
                      : 'text-green-600 bg-green-50'"
                  >
                    {{ formatDaysUntilDue(activity.end_date) }}
                  </span>
                  <span v-else class="text-sm text-gray-400">-</span>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Detail Panel - Overlay on top -->
        <div 
          v-if="selectedActivity"
          class="absolute top-0 right-0 bottom-0 w-96 border-l bg-gray-50 flex flex-col overflow-hidden shadow-xl z-20"
        >
          <div class="p-4 border-b bg-white flex items-center justify-between flex-shrink-0">
            <h3 class="text-lg font-semibold">Task Details</h3>
            <button
              @click="closeDetailPanel"
              class="text-gray-400 hover:text-gray-600 p-1 rounded hover:bg-gray-100"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          
          <div class="flex-1 overflow-y-auto px-6 py-3 space-y-6">
          <!-- Title -->
          <div>
            <h4 class="text-xl font-bold mb-2">{{ selectedActivity.title }}</h4>
            <div v-if="!isEditing && selectedActivity.description" class="text-sm text-gray-600 whitespace-pre-wrap">{{ selectedActivity.description }}</div>
            <textarea
              v-else-if="isEditing"
              v-model="editDescription"
              class="w-full border rounded px-3 py-2 text-sm text-gray-900 resize-none"
              rows="3"
              placeholder="Description"
            />
          </div>
          
            <!-- Context with Accordions -->
            <div class="space-y-2">
              <!-- Objective Accordion -->
              <div class="border border-gray-200 rounded-lg bg-white">
                <div 
                  class="p-3 flex items-center justify-between cursor-pointer hover:bg-gray-50 transition-colors"
                  @click="objectiveExpanded = !objectiveExpanded"
                >
                  <div class="flex items-center gap-2">
                    <div class="text-xs font-semibold text-gray-500 uppercase">Objective</div>
                    <svg 
                      class="w-4 h-4 text-gray-500 transition-transform flex-shrink-0" 
                      :class="{ 'rotate-90': objectiveExpanded }"
                      fill="none" 
                      stroke="currentColor" 
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                  </div>
                </div>
                <div v-if="objectiveExpanded" class="px-3 pb-3 border-t bg-gray-50">
                  <div class="pt-3">
                    <div class="text-sm text-gray-900">
                      <span v-if="selectedActivity.objectiveNumber">{{ selectedActivity.objectiveNumber }}</span>
                      <span v-if="selectedActivity.objectiveNumber && selectedActivity.objectiveTitle">: </span>
                      <span v-if="selectedActivity.objectiveTitle">{{ selectedActivity.objectiveTitle }}</span>
                      <span v-if="!selectedActivity.objectiveNumber && !selectedActivity.objectiveTitle">-</span>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Output Accordion -->
              <div v-if="selectedActivity.outputTitle" class="border border-gray-200 rounded-lg bg-white">
                <div 
                  class="p-3 flex items-center justify-between cursor-pointer hover:bg-gray-50 transition-colors"
                  @click="outputExpanded = !outputExpanded"
                >
                  <div class="flex items-center gap-2">
                    <div class="text-xs font-semibold text-gray-500 uppercase">Output</div>
                    <svg 
                      class="w-4 h-4 text-gray-500 transition-transform flex-shrink-0" 
                      :class="{ 'rotate-90': outputExpanded }"
                      fill="none" 
                      stroke="currentColor" 
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                  </div>
                </div>
                <div v-if="outputExpanded" class="px-3 pb-3 border-t bg-gray-50">
                  <div class="pt-3">
                    <div v-if="selectedActivity.outputNumber" class="text-xs font-semibold text-gray-600 mb-1">
                      Output: {{ selectedActivity.outputNumber }}
                    </div>
                    <div class="text-sm text-gray-900">{{ selectedActivity.outputTitle }}</div>
                  </div>
                </div>
              </div>
            </div>
          
          <!-- Status and Assignee -->
          <div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Status</div>
              <select
                v-if="isEditing"
                v-model="editStatus"
                class="w-full border rounded px-3 py-2 text-sm"
              >
                <option value="not_started">Not Started</option>
                <option value="started">Started</option>
                <option value="in_progress">In Progress</option>
                <option value="review">Review</option>
                <option value="complete">Complete</option>
              </select>
              <span
                v-else
                @click="startEditing"
                class="px-3 py-1 rounded-full text-sm font-medium inline-flex items-center cursor-pointer hover:opacity-80 transition-opacity"
                :class="getStatusColor(selectedActivity.status)"
                title="Click to edit"
              >
                {{ formatStatus(selectedActivity.status) }}
              </span>
            </div>
            <div>
              <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Assignee</div>
              <select
                v-if="isEditing"
                v-model="editAssigneeId"
                class="w-full border rounded px-3 py-2 text-sm"
              >
                <option :value="null">Unassigned</option>
                <option v-for="profile in profiles" :key="profile.id" :value="profile.id">
                  {{ profile.full_name || profile.email || profile.id }}
                </option>
              </select>
                <div v-else class="text-sm text-gray-900">{{ getProfileName(selectedActivity.assignee_id) }}</div>
              </div>
            </div>
          </div>
          
          <!-- Start Date - Due Date - Due -->
          <div>
            <div class="grid grid-cols-3 gap-4">
            <div>
              <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Start Date</div>
              <input
                v-if="isEditing"
                v-model="editStartDate"
                type="date"
                class="w-full border rounded px-3 py-2 text-sm"
              />
              <div v-else-if="selectedActivity.start_date" class="text-sm text-gray-900">{{ formatDate(selectedActivity.start_date) }}</div>
              <div v-else class="text-sm text-gray-400">-</div>
            </div>
            <div>
              <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Due Date</div>
              <input
                v-if="isEditing"
                v-model="editEndDate"
                type="date"
                class="w-full border rounded px-3 py-2 text-sm"
              />
              <div v-else-if="selectedActivity.end_date" class="text-sm text-gray-900">{{ formatDate(selectedActivity.end_date) }}</div>
              <div v-else class="text-sm text-gray-400">-</div>
            </div>
            <div v-if="selectedActivity.end_date && !isEditing">
              <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Due</div>
              <div 
                class="text-sm font-medium"
                :class="getDaysUntilDue(selectedActivity.end_date)! < 0 
                  ? 'text-red-600' 
                  : 'text-green-600'"
              >
                  {{ formatDaysUntilDue(selectedActivity.end_date) }} {{ getDaysUntilDue(selectedActivity.end_date)! < 0 ? 'days overdue' : 'days' }}
                </div>
              </div>
            </div>
          </div>
          
          <!-- Edit Actions -->
          <div class="border-t pt-4 space-y-3">
            <div v-if="!isEditing">
              <button
                @click="startEditing"
                class="w-full bg-blue-600 text-white px-3 py-2 rounded hover:bg-blue-700 text-sm"
              >
                Edit Details
              </button>
            </div>
            
            <div v-else class="space-y-3">
              <div>
                <label class="text-xs font-semibold text-gray-500 uppercase mb-1 block">Notes (optional)</label>
                <textarea
                  v-model="editNotes"
                  class="w-full border rounded px-3 py-2 text-sm resize-none"
                  rows="3"
                  placeholder="Add any notes about this update..."
                />
              </div>
              
              <div class="flex gap-2">
                <button
                  @click="cancelEditing"
                  class="flex-1 px-3 py-2 border rounded text-sm text-gray-700 hover:bg-gray-50"
                  :disabled="saving"
                >
                  Cancel
                </button>
                <button
                  @click="saveChanges"
                  class="flex-1 bg-blue-600 text-white px-3 py-2 rounded hover:bg-blue-700 text-sm"
                  :disabled="saving"
                >
                  {{ saving ? 'Saving...' : 'Save Changes' }}
                </button>
              </div>
            </div>
          </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

