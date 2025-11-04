<script setup lang="ts">
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import { ref, onMounted, computed, watch } from 'vue';
import { updateActivity } from '@/api/activities';
import { useDataStore } from '@/stores/data';

const dataStore = useDataStore();

const calendarError = ref<string | null>(null);
const calendarReady = ref(false);

// Status color mapping for calendar
function getStatusColorForCalendar(status: string) {
  // More transparent colors (using rgba with 40% opacity - 60% transparent)
  const colors = {
    'not_started': 'rgba(156, 163, 175, 0.7)', // gray-400 with 70% opacity
    'started': 'rgba(96, 165, 250, 0.7)', // blue-400 with 70% opacity
    'in_progress': 'rgba(59, 130, 246, 0.7)', // blue-500 with 70% opacity
    'review': 'rgba(251, 191, 36, 0.7)', // yellow-400 with 70% opacity
    'complete': 'rgba(16, 185, 129, 0.7)' // green-500 with 70% opacity
  };
  return colors[status as keyof typeof colors] || 'rgba(156, 163, 175, 0.7)';
}

// Helper: Add 1 day to end date for FullCalendar (end is exclusive)
function addDayForCalendar(dateStr: string | null): string | undefined {
  if (!dateStr) return undefined;
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  date.setDate(date.getDate() + 1);
  const yearStr = date.getFullYear();
  const monthStr = String(date.getMonth() + 1).padStart(2, '0');
  const dayStr = String(date.getDate()).padStart(2, '0');
  return `${yearStr}-${monthStr}-${dayStr}`;
}

// Helper: Subtract 1 day from FullCalendar end date (to convert back to inclusive)
function subtractDayFromCalendar(dateStr: string | null): string | null {
  if (!dateStr) return null;
  const [year, month, day] = dateStr.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  date.setDate(date.getDate() - 1);
  const yearStr = date.getFullYear();
  const monthStr = String(date.getMonth() + 1).padStart(2, '0');
  const dayStr = String(date.getDate()).padStart(2, '0');
  return `${yearStr}-${monthStr}-${dayStr}`;
}

// Events from data store
const events = computed(() => {
  return dataStore.activities
    .filter(a => a.start_date)
    .map(a => ({
      id: a.id,
      title: a.title,
      start: a.start_date ?? undefined,
      // FullCalendar's end is exclusive, so add 1 day to our inclusive end_date
      end: a.end_date ? addDayForCalendar(a.end_date) : (a.start_date ? addDayForCalendar(a.start_date) : undefined),
      backgroundColor: getStatusColorForCalendar(a.status),
      borderColor: 'transparent', // Remove borders
      extendedProps: a,
    }));
});

function load() {
  // Data is reactive from store, no async needed
  calendarReady.value = true;
}

onMounted(() => {
  try {
    load();
  } catch (e: any) {
    console.error('Failed to mount calendar:', e);
    calendarError.value = e?.message || 'Failed to mount calendar';
  }
});

async function onEventDrop(arg: any) {
  const ev = arg.event;
  // FullCalendar's end is exclusive, so subtract 1 day to get our inclusive end_date
  const endDateStr = ev.endStr ? ev.endStr.slice(0, 10) : null;
  await updateActivity(ev.id, {
    start_date: ev.startStr?.slice(0, 10) ?? null,
    end_date: endDateStr ? subtractDayFromCalendar(endDateStr) : (ev.startStr?.slice(0, 10) ?? null),
  });
  await dataStore.refreshActivities();
}
async function onEventResize(arg: any) {
  const ev = arg.event;
  // FullCalendar's end is exclusive, so subtract 1 day to get our inclusive end_date
  const endDateStr = ev.endStr ? ev.endStr.slice(0, 10) : null;
  await updateActivity(ev.id, {
    start_date: ev.startStr?.slice(0, 10) ?? null,
    end_date: endDateStr ? subtractDayFromCalendar(endDateStr) : (ev.startStr?.slice(0, 10) ?? null),
  });
  await dataStore.refreshActivities();
}
</script>

<template>
  <div class="h-full relative z-0">
    <FullCalendar
      v-if="!calendarError && calendarReady"
      :plugins="[dayGridPlugin, timeGridPlugin, interactionPlugin]"
      initialView="dayGridMonth"
      :editable="true"
      :events="events"
      @event-drop="onEventDrop"
      @event-resize="onEventResize"
      height="100%"
    />
    <div v-else-if="calendarError" class="p-4 text-red-600">
      Calendar error: {{ calendarError }}
    </div>
    <div v-else class="p-4 text-gray-500">
      Loading calendar...
    </div>
  </div>
</template>


