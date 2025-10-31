import { defineStore } from 'pinia';
import { listProjects } from '@/api/projects';
import type { Project } from '@/types';

export const useProjectStore = defineStore('project', {
  state: () => ({
    currentProject: null as Project | null,
    projects: [] as Project[],
    loading: false,
  }),
  actions: {
    async loadProjects() {
      this.loading = true;
      try {
        this.projects = await listProjects();
        // If no current project is set, select the first one (or create default)
        if (!this.currentProject && this.projects.length > 0) {
          this.currentProject = this.projects[0];
        }
      } finally {
        this.loading = false;
      }
    },
    setCurrentProject(project: Project | null) {
      this.currentProject = project;
    },
  },
  getters: {
    isProjectSelected: (state) => state.currentProject !== null,
  },
});

