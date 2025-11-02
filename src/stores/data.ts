import { defineStore } from 'pinia';
import { listProjects } from '@/api/projects';
import { listOutcomes } from '@/api/outcomes';
import { listObjectives } from '@/api/objectives';
import { listOutputs } from '@/api/outputs';
import { listAllActivities } from '@/api/activities';
import { listProfiles } from '@/api/profiles';
import type { Project, Outcome, Objective, Output, Activity, Profile, ProgressUpdate } from '@/types';
import { supabase } from '@/lib/supabaseClient';

export const useDataStore = defineStore('data', {
  state: () => ({
    projects: [] as Project[],
    outcomes: [] as Outcome[],
    objectives: [] as Objective[],
    outputs: [] as Output[],
    activities: [] as Activity[],
    profiles: [] as Profile[],
    progressUpdates: [] as ProgressUpdate[],
    loading: false,
    loaded: false,
    error: null as string | null,
  }),
  
  getters: {
    // Get outcomes by project ID
    outcomesByProject: (state) => {
      return (projectId: string) => 
        state.outcomes
          .filter(o => o.project_id === projectId)
          .sort((a, b) => a.title.localeCompare(b.title));
    },
    
    // Get objectives by outcome ID
    objectivesByOutcome: (state) => {
      return (outcomeId: string) => 
        state.objectives
          .filter(o => o.outcome_id === outcomeId)
          .sort((a, b) => {
            // First sort by index (nulls first), then by title
            if (a.index !== null && b.index !== null) {
              return a.index - b.index;
            }
            if (a.index === null && b.index !== null) return -1;
            if (a.index !== null && b.index === null) return 1;
            return a.title.localeCompare(b.title);
          });
    },
    
    // Get outputs by objective ID
    outputsByObjective: (state) => {
      return (objectiveId: string) => 
        state.outputs
          .filter(o => o.objective_id === objectiveId)
          .sort((a, b) => {
            // First sort by index (nulls first), then by title
            if (a.index !== null && b.index !== null) {
              return a.index - b.index;
            }
            if (a.index === null && b.index !== null) return -1;
            if (a.index !== null && b.index === null) return 1;
            return a.title.localeCompare(b.title);
          });
    },
    
    // Get activities by output ID
    activitiesByOutput: (state) => {
      return (outputId: string) => 
        state.activities
          .filter(a => a.output_id === outputId)
          .sort((a, b) => {
            // Sort by start_date (nulls first), then by title
            if (a.start_date && b.start_date) {
              return a.start_date.localeCompare(b.start_date);
            }
            if (!a.start_date && b.start_date) return -1;
            if (a.start_date && !b.start_date) return 1;
            return a.title.localeCompare(b.title);
          });
    },
    
    // Get progress updates by activity ID
    progressUpdatesByActivity: (state) => {
      return (activityId: string) => 
        state.progressUpdates
          .filter(pu => pu.activity_id === activityId)
          .sort((a, b) => b.created_at.localeCompare(a.created_at)); // Most recent first
    },
    
    // Get profile by ID
    profileById: (state) => {
      return (id: string | null) => {
        if (!id) return null;
        return state.profiles.find(p => p.id === id) || null;
      };
    },
  },
  
  actions: {
    async loadAll() {
      if (this.loading) return; // Prevent concurrent loads
      
      this.loading = true;
      this.error = null;
      
      try {
        // Load all data in parallel for better performance
        const [
          projectsData,
          outcomesData,
          objectivesData,
          outputsData,
          activitiesData,
          profilesData,
          progressUpdatesData,
        ] = await Promise.all([
          listProjects(),
          supabase.from('outcomes').select('*').order('title'),
          supabase.from('objectives').select('*').order('index', { nullsFirst: true }).order('title'),
          supabase.from('outputs').select('*').order('index', { nullsFirst: true }).order('title'),
          listAllActivities(),
          listProfiles(),
          supabase.from('progress_updates').select('*').order('created_at', { ascending: false }),
        ]);
        
        this.projects = projectsData;
        this.outcomes = (outcomesData.data || []) as Outcome[];
        this.objectives = (objectivesData.data || []) as Objective[];
        this.outputs = (outputsData.data || []) as Output[];
        this.activities = activitiesData;
        this.profiles = profilesData;
        this.progressUpdates = (progressUpdatesData.data || []) as ProgressUpdate[];
        
        this.loaded = true;
        this.error = null;
      } catch (e: any) {
        console.error('Failed to load data:', e);
        this.error = e?.message || 'Failed to load data';
        throw e;
      } finally {
        this.loading = false;
      }
    },
    
    // Refresh specific data types when they're updated
    async refreshProjects() {
      this.projects = await listProjects();
    },
    
    async refreshOutcomes() {
      const { data } = await supabase.from('outcomes').select('*').order('title');
      this.outcomes = (data || []) as Outcome[];
    },
    
    async refreshObjectives() {
      const { data } = await supabase
        .from('objectives')
        .select('*')
        .order('index', { nullsFirst: true })
        .order('title');
      this.objectives = (data || []) as Objective[];
    },
    
    async refreshOutputs() {
      const { data } = await supabase
        .from('outputs')
        .select('*')
        .order('index', { nullsFirst: true })
        .order('title');
      this.outputs = (data || []) as Output[];
    },
    
    async refreshActivities() {
      this.activities = await listAllActivities();
    },
    
    async refreshProfiles() {
      this.profiles = await listProfiles();
    },
    
    async refreshProgressUpdates() {
      const { data } = await supabase
        .from('progress_updates')
        .select('*')
        .order('created_at', { ascending: false });
      this.progressUpdates = (data || []) as ProgressUpdate[];
    },
    
    // Refresh all data
    async refreshAll() {
      await this.loadAll();
    },
  },
});

