<script setup lang="ts">
import FullCalendar from '@fullcalendar/vue3';
import dayGridPlugin from '@fullcalendar/daygrid';
import timeGridPlugin from '@fullcalendar/timegrid';
import interactionPlugin from '@fullcalendar/interaction';
import { ref, onMounted } from 'vue';
import { listAllActivities, updateActivity } from '@/api/activities';

const events = ref<any[]>([]);
const calendarError = ref<string | null>(null);
const calendarReady = ref(false);

async function load() {
  try {
    const acts = await listAllActivities();
    events.value = acts.map(a => ({
      id: a.id,
      title: a.title,
      start: a.start_date ?? undefined,
      end: a.end_date ?? a.start_date ?? undefined,
      extendedProps: a,
    }));
  } catch (e) {
    console.error('Failed to load activities:', e);
  }
}

onMounted(() => {
  try {
    load().catch(e => {
      console.error('Calendar initialization error:', e);
      calendarError.value = e?.message || 'Failed to initialize calendar';
    });
    calendarReady.value = true;
  } catch (e: any) {
    console.error('Failed to mount calendar:', e);
    calendarError.value = e?.message || 'Failed to mount calendar';
  }
});

async function onEventDrop(arg: any) {
  const ev = arg.event;
  await updateActivity(ev.id, {
    start_date: ev.startStr?.slice(0, 10) ?? null,
    end_date: ev.endStr ? ev.endStr.slice(0, 10) : ev.startStr?.slice(0, 10) ?? null,
  });
  await load();
}
async function onEventResize(arg: any) {
  const ev = arg.event;
  await updateActivity(ev.id, {
    start_date: ev.startStr?.slice(0, 10) ?? null,
    end_date: ev.endStr ? ev.endStr.slice(0, 10) : ev.startStr?.slice(0, 10) ?? null,
  });
  await load();
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


