import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router';
import AuthGate from '@/components/AuthGate.vue';
import AppLayout from '@/components/layout/AppLayout.vue';
import TasksView from '@/components/activities/TasksView.vue';
import CalendarView from '@/components/activities/CalendarView.vue';
import ProgressTrackerView from '@/components/progress/ProgressTrackerView.vue';

const routes: RouteRecordRaw[] = [
  { 
    path: '/', 
    component: AuthGate, 
    children: [
      { path: '', redirect: '/structure' },
      { path: 'structure', component: AppLayout },
      { path: 'activities', component: TasksView },
      { path: 'calendar', component: CalendarView },
      { path: 'progress', component: ProgressTrackerView },
    ]
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;


