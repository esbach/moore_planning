<script setup lang="ts">
import { ref, computed } from 'vue';
import { createProgressUpdate } from '@/api/progressUpdates';
import { updateActivity } from '@/api/activities';
import { useAuthStore } from '@/stores/auth';
import type { Activity, ActivityStatus } from '@/types';
import ProgressHistory from './ProgressHistory.vue';

const props = defineProps<{ 
  activity: Activity;
  currentStatus: ActivityStatus;
}>();

const emit = defineEmits<{ (e: 'updated'): void }>();

const auth = useAuthStore();
const showForm = ref(false);
const showHistory = ref(false);
const status = ref<ActivityStatus>(props.currentStatus);
const notes = ref('');

const canUpdate = computed(() => {
  const profileId = auth.profile?.id;
  return profileId && props.activity.assignee_id === profileId;
});

async function handleSubmit() {
  if (!auth.profile?.id) return;
  
  try {
    // Create progress update history
    await createProgressUpdate(
      props.activity.id,
      auth.profile.id,
      0, // progress no longer used, pass 0
      status.value,
      notes.value || null
    );
    
    // Update the activity itself
    await updateActivity(props.activity.id, {
      status: status.value,
    });
    
    emit('updated');
    showForm.value = false;
    notes.value = '';
    showHistory.value = true; // Auto-show history after update
  } catch (e) {
    console.error('Failed to update progress:', e);
    alert('Failed to update progress. See console for details.');
  }
}

function cancel() {
  showForm.value = false;
  status.value = props.currentStatus;
  notes.value = '';
}
</script>

<template>
  <div>
    <button
      v-if="!showForm && canUpdate"
      @click="showForm = true"
      class="bg-blue-600 text-white px-3 py-1 rounded hover:bg-blue-700 text-sm mt-2"
    >
      Update Progress
    </button>
    
    <div v-if="showForm" class="mt-3 p-3 border rounded bg-gray-50 space-y-3">
      <div>
        <label class="text-xs text-gray-600 mb-1 block">Status</label>
        <select v-model="status" class="border rounded px-3 py-2 w-full">
          <option value="not_started">Not Started</option>
          <option value="started">Started</option>
          <option value="in_progress">In Progress</option>
          <option value="review">Review</option>
          <option value="complete">Complete</option>
        </select>
      </div>
      
      <div>
        <label class="text-xs text-gray-600 mb-1 block">Notes (optional)</label>
        <textarea 
          v-model="notes" 
          class="border rounded px-3 py-2 w-full" 
          rows="3"
          placeholder="Add any notes about your progress..."
        ></textarea>
      </div>
      
      <div class="flex gap-2">
        <button @click="cancel" class="text-sm px-3 py-1">Cancel</button>
        <button 
          @click="handleSubmit" 
          class="bg-blue-600 text-white rounded px-3 py-1 text-sm"
        >
          Save Update
        </button>
      </div>
    </div>
    
    <!-- View History Button -->
    <button
      v-if="!showForm"
      @click="showHistory = !showHistory"
      class="text-blue-600 hover:text-blue-700 text-sm mt-2"
    >
      {{ showHistory ? 'Hide' : 'View' }} Progress History
    </button>
    
    <!-- Progress History -->
    <ProgressHistory 
      v-if="showHistory" 
      :activity-id="activity.id"
    />
  </div>
</template>

