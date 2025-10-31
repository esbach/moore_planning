import { defineStore } from 'pinia';

export const useUiStore = defineStore('ui', {
  state: () => ({
    selectedObjectiveId: null as string | null,
    selectedOutputId: null as string | null,
    selectedAssigneeId: null as string | null,
    statusFilter: null as string | null,
    search: '',
  }),
});


