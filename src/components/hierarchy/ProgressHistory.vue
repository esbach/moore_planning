<script setup lang="ts">
import { computed } from 'vue';
import { useDataStore } from '@/stores/data';
import type { ProgressUpdate } from '@/types';

const props = defineProps<{ activityId: string }>();

const dataStore = useDataStore();

// Get progress updates from data store
const updates = computed(() => dataStore.progressUpdatesByActivity(props.activityId));

// Loading state from data store
const loading = computed(() => dataStore.loading);

function getProfileName(profileId: string | null) {
  if (!profileId) return 'Unknown';
  const profile = dataStore.profileById(profileId);
  return profile?.full_name || profile?.email || 'Unknown';
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleString();
}

function getStatusColor(status: string) {
  const colors = {
    'not_started': 'bg-gray-200',
    'started': 'bg-blue-200',
    'in_progress': 'bg-blue-300',
    'review': 'bg-yellow-200',
    'complete': 'bg-green-200'
  };
  return colors[status as keyof typeof colors] || 'bg-gray-200';
}
</script>

<template>
  <div class="mt-4 border-t pt-4">
    <h4 class="text-sm font-semibold mb-3">Progress History</h4>
    
    <div v-if="loading" class="text-sm text-gray-600">Loading...</div>
    
    <div v-else-if="updates.length === 0" class="text-sm text-gray-500 italic">
      No progress updates yet
    </div>
    
    <div v-else class="space-y-3">
      <div
        v-for="update in updates"
        :key="update.id"
        class="border rounded p-3 bg-gray-50"
      >
        <div class="flex items-start justify-between mb-2">
          <div class="flex items-center gap-2">
            <span 
              class="px-2 py-1 rounded text-xs inline-block"
              :class="getStatusColor(update.status)"
            >
              {{ update.status }}
            </span>
            <span class="text-sm font-medium">{{ update.progress }}%</span>
          </div>
          <div class="text-xs text-gray-500">
            {{ formatDate(update.created_at) }}
          </div>
        </div>
        
        <div class="text-xs text-gray-600">
          By: {{ getProfileName(update.reported_by) }}
        </div>
        
        <p v-if="update.notes" class="text-sm mt-2 text-gray-700">
          {{ update.notes }}
        </p>
      </div>
    </div>
  </div>
</template>

