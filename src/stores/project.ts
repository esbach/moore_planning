import { defineStore } from 'pinia';
import { useDataStore } from './data';
import type { Project } from '@/types';

export const useProjectStore = defineStore('project', {
  state: () => ({
    currentProject: null as Project | null,
    loading: false,
  }),
  actions: {
    loadProjects() {
      // Projects are now loaded from data store
      const dataStore = useDataStore();
      // If no current project is set, select the first one (or create default)
      if (!this.currentProject && dataStore.projects.length > 0) {
        this.currentProject = dataStore.projects[0];
      }
    },
    setCurrentProject(project: Project | null) {
      this.currentProject = project;
    },
  },
  getters: {
    isProjectSelected: (state) => state.currentProject !== null,
    projects: () => {
      const dataStore = useDataStore();
      return dataStore.projects;
    },
  },
});


