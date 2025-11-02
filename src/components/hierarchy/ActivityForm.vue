<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useDataStore } from '@/stores/data';
import type { Activity, ActivityStatus, LinkItem } from '@/types';

const props = defineProps<{ modelValue: boolean; outputId: string; initial?: Partial<Activity> }>();
const emit = defineEmits<{ (e: 'update:modelValue', v: boolean): void; (e: 'save', v: Partial<Activity>): void }>();

const dataStore = useDataStore();

const title = ref(props.initial?.title ?? '');
const description = ref(props.initial?.description ?? '');
const startDate = ref<string | null>(props.initial?.start_date ?? null);
const endDate = ref<string | null>(props.initial?.end_date ?? null);
const status = ref<ActivityStatus>(props.initial?.status ?? 'not_started');
const links = ref<LinkItem[]>(Array.isArray(props.initial?.source_links) ? (props.initial!.source_links as LinkItem[]) : []);
const assigneeId = ref<string | null>((props.initial?.assignee_id as string) ?? null);

// Profiles from data store
const profiles = computed(() => dataStore.profiles);

watch(() => props.initial, (val) => {
  title.value = val?.title ?? '';
  description.value = val?.description ?? '';
  startDate.value = val?.start_date ?? null;
  endDate.value = val?.end_date ?? null;
  status.value = (val?.status as ActivityStatus) ?? 'not_started';
  links.value = Array.isArray(val?.source_links) ? (val!.source_links as LinkItem[]) : [];
  assigneeId.value = val?.assignee_id ?? null;
});

function addLink() { links.value.push({ label: '', url: '' }); }
function removeLink(i: number) { links.value.splice(i, 1); }

const canSave = computed(() => title.value.trim().length > 0);

function onSave() {
  if (!canSave.value) return;
  // Ensure assignee_id is either a valid UUID string or null (not empty string)
  const assigneeIdValue = (assigneeId.value && typeof assigneeId.value === 'string' && assigneeId.value.trim() !== '') 
    ? assigneeId.value.trim() 
    : null;
  emit('save', {
    title: title.value.trim(),
    description: description.value?.trim() || null,
    output_id: props.outputId,
    start_date: startDate.value,
    end_date: endDate.value,
    status: status.value,
    source_links: links.value,
    assignee_id: assigneeIdValue,
  } as Partial<Activity>);
  emit('update:modelValue', false);
}

function onClose() { emit('update:modelValue', false); }
</script>

<template>
  <div v-if="modelValue" class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/40" @click="onClose"></div>
    <div class="relative bg-white rounded shadow-lg w-full max-w-xl p-4 space-y-3">
      <h3 class="text-lg font-semibold">{{ props.initial?.id ? 'Edit' : 'New' }} Task</h3>
      <div class="grid gap-3">
        <input v-model="title" class="border rounded px-3 py-2" placeholder="Title" />
        <textarea v-model="description" class="border rounded px-3 py-2" placeholder="Description"></textarea>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-sm text-gray-600">Start date</label>
            <input v-model="startDate" type="date" class="border rounded px-3 py-2 w-full" />
          </div>
          <div>
            <label class="text-sm text-gray-600">End date</label>
            <input v-model="endDate" type="date" class="border rounded px-3 py-2 w-full" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-sm text-gray-600">Status</label>
            <select v-model="status" class="border rounded px-3 py-2 w-full">
              <option value="not_started">Not Started</option>
              <option value="started">Started</option>
              <option value="in_progress">In Progress</option>
              <option value="review">Review</option>
              <option value="complete">Complete</option>
            </select>
          </div>
          <div>
            <label class="text-sm text-gray-600">Assignee</label>
            <select v-model="assigneeId" class="border rounded px-3 py-2 w-full">
              <option :value="null">Unassigned</option>
              <option v-for="p in profiles" :key="p.id" :value="p.id">
                {{ p.full_name || p.email || p.id }}
              </option>
            </select>
          </div>
        </div>
        <div>
          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-600">Links</label>
            <button class="text-blue-600 text-sm" @click="addLink">Add</button>
          </div>
          <div v-for="(l, i) in links" :key="i" class="flex gap-2 mt-2">
            <input v-model="l.label" class="border rounded px-2 py-1 flex-1" placeholder="Label" />
            <input v-model="l.url" class="border rounded px-2 py-1 flex-[2]" placeholder="https://..." />
            <button class="text-red-600" @click="removeLink(i)">Remove</button>
          </div>
        </div>
      </div>
      <div class="flex justify-end gap-2">
        <button class="px-3 py-2" @click="onClose">Cancel</button>
        <button class="bg-blue-600 text-white rounded px-3 py-2" :disabled="!canSave" @click="onSave">Save</button>
      </div>
    </div>
  </div>
</template>


