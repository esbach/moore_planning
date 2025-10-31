<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useProjectStore } from '@/stores/project';
import { listOutcomes } from '@/api/outcomes';
import { listObjectives } from '@/api/objectives';
import { listOutputs } from '@/api/outputs';
import { listAllActivities } from '@/api/activities';
import NotionSidebar from '@/components/layout/NotionSidebar.vue';
import type { Outcome, Objective, Output, Activity, ActivityStatus } from '@/types';

const projectStore = useProjectStore();
const outcomes = ref<Outcome[]>([]);
const objectivesMap = ref<Record<string, Objective[]>>({});
const outputsMap = ref<Record<string, Output[]>>({});
const allActivities = ref<Activity[]>([]);
const selectedObjectiveId = ref<string | null>(null);
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
    // Load outcomes
    outcomes.value = await listOutcomes(projectStore.currentProject.id);
    
    // Load objectives for all outcomes
    const objectivesEntries = await Promise.all(
      outcomes.value.map(async (outcome) => {
        const objs = await listObjectives(outcome.id);
        return [outcome.id, objs] as const;
      })
    );
    objectivesMap.value = Object.fromEntries(objectivesEntries);
    
    // Load outputs for all objectives
    const allObjectives = Object.values(objectivesMap.value).flat();
    const outputsEntries = await Promise.all(
      allObjectives.map(async (obj) => {
        const outputs = await listOutputs(obj.id);
        return [obj.id, outputs] as const;
      })
    );
    outputsMap.value = Object.fromEntries(outputsEntries);
    
    // Load all activities
    allActivities.value = await listAllActivities();
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

// Calculate progress for each objective
const objectiveProgressList = computed((): ObjectiveProgress[] => {
  return Object.values(objectivesMap.value).flat().map(objective => {
    const outputs = outputsMap.value[objective.id] || [];
    const outputProgresses: OutputProgress[] = outputs.map(output => {
      const tasks = allActivities.value.filter(a => a.output_id === output.id);
      const statusCount = calculateStatusCount(tasks);
      const completionRate = calculateCompletionRate(statusCount);
      
      return {
        output,
        tasks,
        statusCount,
        completionRate
      };
    });
    
    // Aggregate objective-level stats
    const allTasks = outputProgresses.flatMap(op => op.tasks);
    const statusCount = calculateStatusCount(allTasks);
    const completionRate = calculateCompletionRate(statusCount);
    
    return {
      objective,
      outputs: outputProgresses.sort((a, b) => {
        if (b.completionRate !== a.completionRate) {
          return b.completionRate - a.completionRate;
        }
        return b.statusCount.total - a.statusCount.total;
      }),
      statusCount,
      completionRate
    };
  }).sort((a, b) => {
    if (b.completionRate !== a.completionRate) {
      return b.completionRate - a.completionRate;
    }
    return b.statusCount.total - a.statusCount.total;
  });
});

const selectedObjectiveProgress = computed(() => {
  if (!selectedObjectiveId.value) return null;
  return objectiveProgressList.value.find(
    op => op.objective.id === selectedObjectiveId.value
  ) || null;
});

onMounted(async () => {
  await projectStore.loadProjects();
  await loadData();
});

watch(() => projectStore.currentProject, () => {
  selectedObjectiveId.value = null;
  loadData();
});
</script>

<template>
  <div class="h-screen flex">
    <!-- Notion-style Sidebar -->
    <NotionSidebar />
    
    <div class="flex-1 flex overflow-hidden">
      <!-- Left Panel: Objectives List -->
      <div class="w-80 border-r bg-white overflow-auto flex-shrink-0">
        <div class="p-4 border-b">
          <h2 class="text-xl font-bold text-gray-900">Progress Tracker</h2>
          <p class="text-sm text-gray-500 mt-1">Select an objective to view progress</p>
        </div>
        
        <div v-if="loading" class="p-4 text-sm text-gray-600">Loading...</div>
        
        <div v-else-if="objectiveProgressList.length === 0" class="p-4 text-sm text-gray-500 italic">
          No objectives found
        </div>
        
        <div v-else class="divide-y">
          <div
            v-for="objProg in objectiveProgressList"
            :key="objProg.objective.id"
            @click="selectedObjectiveId = objProg.objective.id"
            class="p-4 cursor-pointer hover:bg-gray-50 transition-colors"
            :class="{ 'bg-blue-50 border-l-4 border-blue-500': selectedObjectiveId === objProg.objective.id }"
          >
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2">
                <span class="text-xs font-semibold text-gray-600">
                  {{ objProg.objective.short_name || (objProg.objective.index !== null && objProg.objective.index !== undefined ? `Obj ${objProg.objective.index + 1}` : 'Objective') }}
                </span>
                <div class="text-lg font-bold text-blue-600">{{ objProg.completionRate }}%</div>
              </div>
            </div>
            <p class="text-sm font-medium text-gray-900 mb-2">{{ objProg.objective.title }}</p>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div 
                class="bg-blue-600 h-2 rounded-full transition-all"
                :style="{ width: objProg.completionRate + '%' }"
              ></div>
            </div>
            <div class="text-xs text-gray-500 mt-2">
              {{ objProg.statusCount.complete }}/{{ objProg.statusCount.total }} tasks complete
            </div>
          </div>
        </div>
      </div>
      
      <!-- Right Panel: Detailed Progress -->
      <div class="flex-1 overflow-auto bg-gray-50">
        <div v-if="!selectedObjectiveProgress" class="flex items-center justify-center h-full text-gray-500">
          <div class="text-center">
            <p class="text-lg mb-2">Select an Objective</p>
            <p class="text-sm">Choose an objective from the left panel to view detailed progress</p>
          </div>
        </div>
        
        <div v-else class="p-6 space-y-6">
          <!-- Objective Level Summary -->
          <div class="border rounded-lg p-6 bg-white shadow-sm">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h3 class="text-2xl font-bold text-gray-900">
                  {{ selectedObjectiveProgress.objective.short_name || (selectedObjectiveProgress.objective.index !== null && selectedObjectiveProgress.objective.index !== undefined ? `Objective ${selectedObjectiveProgress.objective.index + 1}` : 'Objective') }}
                </h3>
                <p class="text-sm text-gray-700 mt-1">{{ selectedObjectiveProgress.objective.title }}</p>
              </div>
              <div class="text-4xl font-bold text-blue-600">{{ selectedObjectiveProgress.completionRate }}%</div>
            </div>
            
            <!-- Progress Bar -->
            <div class="w-full bg-gray-200 rounded-full h-4 mb-4">
              <div 
                class="bg-blue-600 h-4 rounded-full transition-all"
                :style="{ width: selectedObjectiveProgress.completionRate + '%' }"
              ></div>
            </div>
            
            <!-- Status Breakdown -->
            <div class="flex gap-4 flex-wrap">
              <div class="flex items-center gap-2 text-sm">
                <div class="w-4 h-4 rounded bg-gray-400"></div>
                <span class="text-gray-600">{{ selectedObjectiveProgress.statusCount.not_started }} Not Started</span>
              </div>
              <div class="flex items-center gap-2 text-sm">
                <div class="w-4 h-4 rounded bg-blue-300"></div>
                <span class="text-gray-600">{{ selectedObjectiveProgress.statusCount.started }} Started</span>
              </div>
              <div class="flex items-center gap-2 text-sm">
                <div class="w-4 h-4 rounded bg-blue-500"></div>
                <span class="text-gray-600">{{ selectedObjectiveProgress.statusCount.in_progress }} In Progress</span>
              </div>
              <div class="flex items-center gap-2 text-sm">
                <div class="w-4 h-4 rounded bg-yellow-400"></div>
                <span class="text-gray-600">{{ selectedObjectiveProgress.statusCount.review }} Review</span>
              </div>
              <div class="flex items-center gap-2 text-sm">
                <div class="w-4 h-4 rounded bg-green-400"></div>
                <span class="text-gray-600">{{ selectedObjectiveProgress.statusCount.complete }} Complete</span>
              </div>
              <div class="text-sm text-gray-500">
                ({{ selectedObjectiveProgress.statusCount.total }} total)
              </div>
            </div>
          </div>

          <!-- Outputs Progress Matrix -->
          <div class="space-y-4">
            <h4 class="font-semibold text-gray-900 text-lg">Outputs Progress</h4>
            
            <div v-if="selectedObjectiveProgress.outputs.length === 0" class="text-sm text-gray-500 italic text-center py-8 bg-white rounded-lg border">
              No outputs yet
            </div>
            
            <div v-else class="space-y-4">
              <div
                v-for="outputProg in selectedObjectiveProgress.outputs"
                :key="outputProg.output.id"
                class="border rounded-lg p-5 bg-white shadow-sm"
              >
                <div class="flex items-center justify-between mb-3">
                  <h5 class="font-semibold text-lg text-gray-900">{{ outputProg.output.title }}</h5>
                  <div class="text-2xl font-bold text-gray-700">{{ outputProg.completionRate }}%</div>
                </div>
                
                <!-- Progress Bar -->
                <div class="w-full bg-gray-200 rounded-full h-3 mb-4">
                  <div 
                    class="bg-blue-600 h-3 rounded-full transition-all"
                    :style="{ width: outputProg.completionRate + '%' }"
                  ></div>
                </div>
                
                <!-- Status Breakdown -->
                <div class="grid grid-cols-5 gap-3 mb-4">
                  <div class="text-center">
                    <div class="text-xl font-bold text-gray-700">{{ outputProg.statusCount.not_started }}</div>
                    <div class="text-xs text-gray-500">Not Started</div>
                  </div>
                  <div class="text-center">
                    <div class="text-xl font-bold text-gray-700">{{ outputProg.statusCount.started }}</div>
                    <div class="text-xs text-gray-500">Started</div>
                  </div>
                  <div class="text-center">
                    <div class="text-xl font-bold text-gray-700">{{ outputProg.statusCount.in_progress }}</div>
                    <div class="text-xs text-gray-500">In Progress</div>
                  </div>
                  <div class="text-center">
                    <div class="text-xl font-bold text-gray-700">{{ outputProg.statusCount.review }}</div>
                    <div class="text-xs text-gray-500">Review</div>
                  </div>
                  <div class="text-center">
                    <div class="text-xl font-bold text-gray-700">{{ outputProg.statusCount.complete }}</div>
                    <div class="text-xs text-gray-500">Complete</div>
                  </div>
                </div>
                
                <!-- Task List (Ranked) -->
                <div v-if="outputProg.tasks.length > 0" class="pt-4 border-t">
                  <div class="text-xs font-semibold text-gray-500 uppercase mb-3">Tasks (ranked by progress)</div>
                  <div class="space-y-2">
                    <div
                      v-for="task in [...outputProg.tasks].sort((a, b) => {
                        const aRank = statusOrder[a.status] || 0;
                        const bRank = statusOrder[b.status] || 0;
                        if (bRank !== aRank) return bRank - aRank;
                        return a.title.localeCompare(b.title);
                      })"
                      :key="task.id"
                      class="flex items-center justify-between py-2 px-3 rounded hover:bg-gray-50 text-sm"
                    >
                      <span class="text-gray-700 flex-1 truncate">{{ task.title }}</span>
                      <span 
                        class="px-2.5 py-1 rounded text-xs font-medium ml-3 flex-shrink-0"
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
                
                <div v-else class="pt-4 border-t text-sm text-gray-500 italic">
                  No tasks yet
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

