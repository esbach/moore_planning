<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { listOutputs } from '@/api/outputs';
import { listAllActivities } from '@/api/activities';
import { listObjectives } from '@/api/objectives';
import { listOutcomes } from '@/api/outcomes';
import { useProjectStore } from '@/stores/project';
import type { Objective, Output, Activity, Outcome, ActivityStatus } from '@/types';

const props = defineProps<{ objective: Objective }>();
const projectStore = useProjectStore();

const outputs = ref<Output[]>([]);
const allActivities = ref<Activity[]>([]);
const outcome = ref<Outcome | null>(null);
const loading = ref(false);

// Status order for ranking (higher = more complete)
const statusOrder: Record<ActivityStatus, number> = {
  'not_started': 0,
  'started': 1,
  'in_progress': 2,
  'review': 3,
  'complete': 4
};

interface StatusCount {
  not_started: number;
  started: number;
  in_progress: number;
  review: number;
  complete: number;
  total: number;
}

interface OutputProgress {
  output: Output;
  tasks: Activity[];
  statusCount: StatusCount;
  completionRate: number;
}

interface ObjectiveProgress {
  objective: Objective;
  outputs: OutputProgress[];
  statusCount: StatusCount;
  completionRate: number;
}

async function loadData() {
  if (!projectStore.currentProject) return;
  
  loading.value = true;
  try {
    // Load outcome
    const outcomes = await listOutcomes(projectStore.currentProject.id);
    outcome.value = outcomes[0] || null;
    
    // Load outputs for this objective
    outputs.value = await listOutputs(props.objective.id);
    
    // Load all activities for this objective (through all outputs)
    const allOutputIds = outputs.value.map(o => o.id);
    const allActs = await listAllActivities();
    allActivities.value = allActs.filter(a => allOutputIds.includes(a.output_id));
  } catch (e) {
    console.error('Failed to load progress data:', e);
  } finally {
    loading.value = false;
  }
}

function calculateStatusCount(activities: Activity[]): StatusCount {
  const count: StatusCount = {
    not_started: 0,
    started: 0,
    in_progress: 0,
    review: 0,
    complete: 0,
    total: activities.length
  };
  
  activities.forEach(a => {
    if (a.status in count) {
      count[a.status as keyof StatusCount]++;
    }
  });
  
  return count;
}

function calculateCompletionRate(statusCount: StatusCount): number {
  if (statusCount.total === 0) return 0;
  return Math.round((statusCount.complete / statusCount.total) * 100);
}

// Group activities by output and calculate progress
const outputProgress = computed((): OutputProgress[] => {
  return outputs.value.map(output => {
    const tasks = allActivities.value.filter(a => a.output_id === output.id);
    const statusCount = calculateStatusCount(tasks);
    const completionRate = calculateCompletionRate(statusCount);
    
    return {
      output,
      tasks,
      statusCount,
      completionRate
    };
  }).sort((a, b) => {
    // Sort by completion rate (descending), then by total tasks
    if (b.completionRate !== a.completionRate) {
      return b.completionRate - a.completionRate;
    }
    return b.statusCount.total - a.statusCount.total;
  });
});

// Calculate objective-level progress
const objectiveProgress = computed((): ObjectiveProgress => {
  const allTasks = allActivities.value;
  const statusCount = calculateStatusCount(allTasks);
  const completionRate = calculateCompletionRate(statusCount);
  
  return {
    objective: props.objective,
    outputs: outputProgress.value,
    statusCount,
    completionRate
  };
});

onMounted(loadData);
watch(() => props.objective.id, loadData);
</script>

<template>
  <div class="h-full flex flex-col bg-white">
    <div v-if="loading" class="text-sm text-gray-600 p-4">Loading progress data...</div>
    
    <div v-else class="flex-1 flex flex-col overflow-hidden">
      <!-- Header -->
      <div class="p-4 border-b flex-shrink-0">
        <h3 class="font-semibold text-gray-900">Progress Tracker</h3>
      </div>

      <!-- Content -->
      <div class="flex-1 overflow-auto p-4 space-y-6">
        <!-- Objective Level Summary -->
        <div class="border rounded-lg p-4 bg-gray-50">
          <div class="flex items-center justify-between mb-3">
            <h4 class="font-semibold text-gray-900">
              Objective: {{ objective.short_name || (objective.index !== null && objective.index !== undefined ? `Obj ${objective.index + 1}` : 'Objective') }}
            </h4>
            <div class="text-2xl font-bold text-blue-600">{{ objectiveProgress.completionRate }}%</div>
          </div>
          <p class="text-sm text-gray-700 mb-3">{{ objective.title }}</p>
          
          <!-- Progress Bar -->
          <div class="w-full bg-gray-200 rounded-full h-3 mb-3">
            <div 
              class="bg-blue-600 h-3 rounded-full transition-all"
              :style="{ width: objectiveProgress.completionRate + '%' }"
            ></div>
          </div>
          
          <!-- Status Breakdown -->
          <div class="flex gap-2 flex-wrap">
            <div class="flex items-center gap-1 text-xs">
              <div class="w-3 h-3 rounded bg-gray-400"></div>
              <span class="text-gray-600">{{ objectiveProgress.statusCount.not_started }} Not Started</span>
            </div>
            <div class="flex items-center gap-1 text-xs">
              <div class="w-3 h-3 rounded bg-blue-300"></div>
              <span class="text-gray-600">{{ objectiveProgress.statusCount.started }} Started</span>
            </div>
            <div class="flex items-center gap-1 text-xs">
              <div class="w-3 h-3 rounded bg-blue-500"></div>
              <span class="text-gray-600">{{ objectiveProgress.statusCount.in_progress }} In Progress</span>
            </div>
            <div class="flex items-center gap-1 text-xs">
              <div class="w-3 h-3 rounded bg-yellow-400"></div>
              <span class="text-gray-600">{{ objectiveProgress.statusCount.review }} Review</span>
            </div>
            <div class="flex items-center gap-1 text-xs">
              <div class="w-3 h-3 rounded bg-green-400"></div>
              <span class="text-gray-600">{{ objectiveProgress.statusCount.complete }} Complete</span>
            </div>
            <div class="text-xs text-gray-500 ml-2">
              ({{ objectiveProgress.statusCount.total }} total)
            </div>
          </div>
        </div>

        <!-- Outputs Progress Matrix -->
        <div class="space-y-4">
          <h4 class="font-semibold text-gray-900 text-sm">Outputs Progress</h4>
          
          <div v-if="outputProgress.length === 0" class="text-sm text-gray-500 italic text-center py-8">
            No outputs yet
          </div>
          
          <div v-else class="space-y-3">
            <div
              v-for="outputProg in outputProgress"
              :key="outputProg.output.id"
              class="border rounded-lg p-4 bg-white"
            >
              <div class="flex items-center justify-between mb-2">
                <h5 class="font-medium text-sm text-gray-900">{{ outputProg.output.title }}</h5>
                <div class="text-lg font-bold text-gray-700">{{ outputProg.completionRate }}%</div>
              </div>
              
              <!-- Progress Bar -->
              <div class="w-full bg-gray-200 rounded-full h-2 mb-3">
                <div 
                  class="bg-blue-600 h-2 rounded-full transition-all"
                  :style="{ width: outputProg.completionRate + '%' }"
                ></div>
              </div>
              
              <!-- Status Breakdown -->
              <div class="grid grid-cols-5 gap-2 text-xs">
                <div class="text-center">
                  <div class="font-semibold text-gray-600">{{ outputProg.statusCount.not_started }}</div>
                  <div class="text-gray-500">Not Started</div>
                </div>
                <div class="text-center">
                  <div class="font-semibold text-gray-600">{{ outputProg.statusCount.started }}</div>
                  <div class="text-gray-500">Started</div>
                </div>
                <div class="text-center">
                  <div class="font-semibold text-gray-600">{{ outputProg.statusCount.in_progress }}</div>
                  <div class="text-gray-500">In Progress</div>
                </div>
                <div class="text-center">
                  <div class="font-semibold text-gray-600">{{ outputProg.statusCount.review }}</div>
                  <div class="text-gray-500">Review</div>
                </div>
                <div class="text-center">
                  <div class="font-semibold text-gray-600">{{ outputProg.statusCount.complete }}</div>
                  <div class="text-gray-500">Complete</div>
                </div>
              </div>
              
              <!-- Task List (Ranked) -->
              <div v-if="outputProg.tasks.length > 0" class="mt-3 pt-3 border-t">
                <div class="text-xs font-semibold text-gray-500 uppercase mb-2">Tasks (ranked by progress)</div>
                <div class="space-y-1">
                  <div
                    v-for="task in [...outputProg.tasks].sort((a, b) => {
                      const aRank = statusOrder[a.status] || 0;
                      const bRank = statusOrder[b.status] || 0;
                      if (bRank !== aRank) return bRank - aRank;
                      return a.title.localeCompare(b.title);
                    })"
                    :key="task.id"
                    class="flex items-center justify-between text-xs py-1 px-2 rounded hover:bg-gray-50"
                  >
                    <span class="text-gray-700 truncate flex-1">{{ task.title }}</span>
                    <span 
                      class="px-2 py-0.5 rounded text-xs ml-2 flex-shrink-0"
                      :class="{
                        'bg-gray-100 text-gray-700': task.status === 'not_started',
                        'bg-blue-100 text-blue-700': task.status === 'started',
                        'bg-blue-200 text-blue-800': task.status === 'in_progress',
                        'bg-yellow-100 text-yellow-800': task.status === 'review',
                        'bg-green-100 text-green-700': task.status === 'complete'
                      }"
                    >
                      {{ task.status === 'not_started' ? 'Not Started' :
                         task.status === 'started' ? 'Started' :
                         task.status === 'in_progress' ? 'In Progress' :
                         task.status === 'review' ? 'Review' :
                         'Complete' }}
                    </span>
                  </div>
                </div>
              </div>
              
              <div v-else class="mt-3 pt-3 border-t text-xs text-gray-500 italic">
                No tasks yet
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

