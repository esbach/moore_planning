export type UUID = string;

export interface Project {
  id: UUID;
  name: string;
  description: string | null;
  created_at: string;
  created_by: UUID | null;
}

export interface Outcome {
  id: UUID;
  project_id: UUID | null;
  title: string;
  description: string | null;
}

export interface Objective {
  id: UUID;
  outcome_id: UUID;
  title: string;
  description: string | null;
  index: number | null;
  short_name: string | null;
}

export interface Output {
  id: UUID;
  objective_id: UUID;
  title: string;
  description: string | null;
  index: number | null;
}

export interface LinkItem { label: string; url: string }

export type ActivityStatus = 'not_started' | 'started' | 'in_progress' | 'review' | 'complete';
export type Priority = 'low' | 'medium' | 'high';

export interface Activity {
  id: UUID;
  output_id: UUID;
  title: string;
  description: string | null;
  assignee_id: UUID | null;
  start_date: string | null; // ISO date
  end_date: string | null;   // ISO date
  progress: number;
  status: ActivityStatus;
  priority: Priority;
  source_links: LinkItem[];
}

export interface Profile {
  id: UUID;
  full_name: string | null;
  email: string | null;
  is_admin?: boolean;
}

export interface ProgressUpdate {
  id: UUID;
  activity_id: UUID;
  reported_by: UUID | null;
  progress: number;
  status: ActivityStatus;
  notes: string | null;
  created_at: string;
}


