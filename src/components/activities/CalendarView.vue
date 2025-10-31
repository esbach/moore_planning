<script setup lang="ts">
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import { ref, onMounted, computed, watch } from 'vue';
import { listAllActivities, updateActivity } from '@/api/activities';
import { listProfiles } from '@/api/profiles';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/lib/supabaseClient';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';
import type { Activity, Profile, Output, Objective, ActivityStatus } from '@/types';

const auth = useAuthStore();

interface ActivityWithContext extends Activity {
  objectiveNumber: string | null;
  objectiveTitle: string | null;
  outputTitle: string | null;
}

const events = ref<any[]>([]);
const loading = ref(true);
const calendarError = ref<string | null>(null);
const calendarReady = ref(false);
const selectedActivity = ref<ActivityWithContext | null>(null);
const allActivities = ref<Activity[]>([]);
const activitiesWithContext = ref<ActivityWithContext[]>([]);
const profiles = ref<Profile[]>([]);

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

const calendarOptions = computed(() => ({
  plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin],
  initialView: 'dayGridMonth',
  editable: true,
  events: events.value,
  eventClick: handleEventClick,
}));

function handleEventClick(arg: any) {
  const activityId = arg.event.id;
  selectedActivity.value = activitiesWithContext.value.find(a => a.id === activityId) || null;
}

async function load() {
  try {
    loading.value = true;
    const acts = await listAllActivities();
    profiles.value = await listProfiles();
    
    // Fetch all outputs and objectives to build context
    const { data: outputs } = await supabase.from('outputs').select('*');
    const { data: objectives } = await supabase.from('objectives').select('*');
    
    if (!outputs || !objectives) {
      throw new Error('Failed to load outputs or objectives');
    }
    
    // Build maps for quick lookup
    const outputMap = new Map<string, Output>(outputs.map(o => [o.id, o]));
    const objectiveMap = new Map<string, Objective>(objectives.map(o => [o.id, o]));
    
    // Enrich activities with context
    activitiesWithContext.value = acts.map(activity => {
      const output = outputMap.get(activity.output_id);
      const objective = output ? objectiveMap.get(output.objective_id) : null;
      
      return {
        ...activity,
        objectiveNumber: objective 
          ? (objective.short_name || (objective.index !== null && objective.index !== undefined ? `Obj ${objective.index + 1}` : null))
          : null,
        objectiveTitle: objective?.title || null,
        outputTitle: output?.title || null,
      };
    });
    
    allActivities.value = acts;
    events.value = acts
      .filter(a => a.start_date) // Only show activities with dates
      .map(a => ({
        id: a.id,
        title: a.title,
        start: a.start_date!,
        end: a.end_date ?? a.start_date!,
        backgroundColor: getStatusColorForCalendar(a.status),
        extendedProps: a,
      }));
    
    // Refresh selected activity if it exists
    if (selectedActivity.value) {
      const updated = activitiesWithContext.value.find(a => a.id === selectedActivity.value?.id);
      if (updated) {
        selectedActivity.value = updated;
      }
    }
  } catch (e) {
    console.error('Failed to load activities:', e);
  } finally {
    loading.value = false;
  }
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

function getStatusColorForCalendar(status: string) {
  const colors = {
    'not_started': '#9ca3af',
    'started': '#60a5fa',
    'in_progress': '#3b82f6',
    'review': '#fbbf24',
    'complete': '#10b981'
  };
  return colors[status as keyof typeof colors] || '#9ca3af';
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

function getProfileName(profileId: string | null) {
  if (!profileId) return 'Unassigned';
  const profile = profiles.value.find(p => p.id === profileId);
  return profile?.full_name || profile?.email || 'Unknown';
}

function formatDate(dateStr: string | null) {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const year = date.getFullYear();
  return `${month}/${day}/${year}`;
}

function getDaysUntilDue(endDate: string | null): number | null {
  if (!endDate) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const due = new Date(endDate);
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
    
    await load();
    isEditing.value = false;
    editNotes.value = '';
  } catch (e) {
    console.error('Failed to save changes:', e);
    alert('Failed to save changes. See console for details.');
  } finally {
    saving.value = false;
  }
}

// Reset editing when activity changes
watch(() => selectedActivity.value?.id, () => {
  isEditing.value = false;
  editNotes.value = '';
  objectiveExpanded.value = false; // Reset to closed
  outputExpanded.value = true; // Reset to open
});

onMounted(async () => {
  try {
    await load();
    calendarReady.value = true;
  } catch (e: any) {
    console.error('Calendar initialization error:', e);
    calendarError.value = e?.message || 'Failed to initialize calendar';
    calendarReady.value = true; // Still set ready so error shows
  }
});

async function onEventDrop(arg: any) {
  const ev = arg.event;
  try {
    await updateActivity(ev.id, {
      start_date: ev.startStr?.slice(0, 10) ?? null,
      end_date: ev.endStr ? ev.endStr.slice(0, 10) : ev.startStr?.slice(0, 10) ?? null,
    });
    await load();
  } catch (e) {
    console.error('Failed to update activity:', e);
    await load(); // Reload to revert
  }
}

async function onEventResize(arg: any) {
  const ev = arg.event;
  try {
    await updateActivity(ev.id, {
      start_date: ev.startStr?.slice(0, 10) ?? null,
      end_date: ev.endStr ? ev.endStr.slice(0, 10) : ev.startStr?.slice(0, 10) ?? null,
    });
    await load();
  } catch (e) {
    console.error('Failed to update activity:', e);
    await load(); // Reload to revert
  }
}
</script>

<template>
  <div class="h-screen flex">
    <!-- Notion-style Sidebar -->
    <NotionSidebar />
    
    <div class="flex-1 flex flex-col bg-white overflow-hidden">
      <!-- Header -->
      <div class="p-4 border-b">
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-bold">Calendar</h2>
          <div class="flex items-center gap-4 text-xs">
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded bg-gray-400"></div>
              <span>Not Started</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded bg-blue-300"></div>
              <span>Started</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded bg-blue-500"></div>
              <span>In Progress</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded bg-yellow-400"></div>
              <span>Review</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded bg-green-400"></div>
              <span>Complete</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Calendar and Details Sidebar -->
      <div class="flex-1 flex overflow-hidden" style="min-height: 0;">
        <!-- Calendar (2/3 width) -->
        <div class="w-2/3 p-4 overflow-auto">
          <div v-if="loading" class="flex items-center justify-center h-full">
            <p class="text-gray-500">Loading calendar...</p>
          </div>
          <div v-else-if="calendarError" class="flex items-center justify-center h-full">
            <div class="text-center">
              <p class="text-red-600 font-semibold mb-2">Calendar Error</p>
              <p class="text-gray-600 text-sm">{{ calendarError }}</p>
            </div>
          </div>
          <div v-else-if="calendarReady && !calendarError" style="height: 600px;">
            <FullCalendar
              :options="calendarOptions"
              @event-drop="onEventDrop"
              @event-resize="onEventResize"
            />
          </div>
          <div v-else class="flex items-center justify-center h-full">
            <p class="text-gray-500">Initializing calendar...</p>
          </div>
        </div>
        
        <!-- Details Sidebar - Same as ActivitiesView -->
        <div 
          v-if="selectedActivity"
          class="w-96 border-l bg-gray-50 flex flex-col overflow-hidden flex-shrink-0"
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
          
          <div class="flex-1 overflow-y-auto p-4 space-y-6">
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
                    <div class="text-sm text-gray-900">{{ selectedActivity.outputTitle }}</div>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Status and Assignee -->
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
            
            <!-- Start Date - Due Date - Due -->
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
        
        <!-- Empty state when no activity selected -->
        <div 
          v-else
          class="w-1/3 border-l bg-gray-50 flex items-center justify-center"
        >
          <div class="text-center text-gray-500">
            <p class="text-lg mb-2">Select an Activity</p>
            <p class="text-sm">Click on a calendar event to view details</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
