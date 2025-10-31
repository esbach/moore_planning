<script setup lang="ts">
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import { ref, onMounted, computed } from 'vue';
import { listAllActivities, updateActivity } from '@/api/activities';
import { useAuthStore } from '@/stores/auth';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';

const auth = useAuthStore();

const events = ref<any[]>([]);
const loading = ref(true);
const calendarError = ref<string | null>(null);
const calendarReady = ref(false);
const selectedActivity = ref<any>(null);
const allActivities = ref<any[]>([]);

const calendarOptions = computed(() => ({
  plugins: [dayGridPlugin, timeGridPlugin, interactionPlugin],
  initialView: 'dayGridMonth',
  editable: true,
  events: events.value,
  eventClick: handleEventClick,
}));

function handleEventClick(arg: any) {
  const activityId = arg.event.id;
  selectedActivity.value = allActivities.value.find(a => a.id === activityId) || null;
}

async function load() {
  try {
    loading.value = true;
    const acts = await listAllActivities();
    console.log('Loaded activities:', acts);
    allActivities.value = acts;
    events.value = acts
      .filter(a => a.start_date) // Only show activities with dates
      .map(a => ({
        id: a.id,
        title: a.title,
        start: a.start_date!,
        end: a.end_date ?? a.start_date!,
        backgroundColor: getStatusColor(a.status),
        extendedProps: a,
      }));
    console.log('Calendar events:', events.value);
    if (events.value.length === 0) {
      console.warn('No activities with dates found. Add start_date to activities to see them in the calendar.');
      // Add test event to verify calendar works
      events.value = [{
        title: 'Test Event - Add dates to your activities!',
        start: new Date().toISOString().split('T')[0],
        backgroundColor: '#3b82f6',
      }];
    }
  } catch (e) {
    console.error('Failed to load activities:', e);
  } finally {
    loading.value = false;
  }
}

function getStatusColor(status: string) {
  const colors = {
    'not_started': '#9ca3af',
    'started': '#60a5fa',
    'in_progress': '#3b82f6',
    'review': '#fbbf24',
    'complete': '#10b981'
  };
  return colors[status as keyof typeof colors] || '#9ca3af';
}

function getStatusBgColor(status: string) {
  const bgColors = {
    'not_started': 'bg-gray-200',
    'started': 'bg-blue-200',
    'in_progress': 'bg-blue-300',
    'review': 'bg-yellow-200',
    'complete': 'bg-green-200'
  };
  return bgColors[status as keyof typeof bgColors] || 'bg-gray-200';
}

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
        
        <!-- Details Sidebar (1/3 width) -->
        <div class="w-1/3 border-l bg-gray-50 overflow-auto">
          <div v-if="!selectedActivity" class="flex items-center justify-center h-full">
            <div class="text-center text-gray-500">
              <p class="text-lg mb-2">Select an Activity</p>
              <p class="text-sm">Click on a calendar event to view details</p>
            </div>
          </div>
          <div v-else class="p-4">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-xl font-bold">{{ selectedActivity.title }}</h3>
              <button 
                @click="selectedActivity = null"
                class="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>
            
            <div class="space-y-4">
              <div v-if="selectedActivity.description">
                <h4 class="font-semibold text-sm text-gray-700 mb-1">Description</h4>
                <p class="text-sm text-gray-600">{{ selectedActivity.description }}</p>
              </div>
              
              <div>
                <h4 class="font-semibold text-sm text-gray-700 mb-1">Status</h4>
                <span 
                  class="px-2 py-1 rounded text-xs inline-block"
                  :class="getStatusBgColor(selectedActivity.status)"
                >
                  {{ selectedActivity.status }}
                </span>
              </div>
              
              <div v-if="selectedActivity.start_date">
                <h4 class="font-semibold text-sm text-gray-700 mb-1">Start Date</h4>
                <p class="text-sm text-gray-600">{{ new Date(selectedActivity.start_date).toLocaleDateString() }}</p>
              </div>
              
              <div v-if="selectedActivity.end_date">
                <h4 class="font-semibold text-sm text-gray-700 mb-1">End Date</h4>
                <p class="text-sm text-gray-600">{{ new Date(selectedActivity.end_date).toLocaleDateString() }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
