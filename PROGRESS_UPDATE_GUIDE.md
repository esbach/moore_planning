# Progress Update System

## Overview

You can now track progress updates for your activities with full history!

## What Was Added

### Database Schema
- **New table**: `progress_updates` - stores all progress update history
  - Tracks: progress %, status, notes, who reported it, and when
  - Automatically cleans up when activities are deleted (cascade)

### Components
1. **ProgressUpdateForm** - Form to update progress on your assigned activities
2. **ProgressHistory** - View all historical progress updates for an activity

### API
- New file: `src/api/progressUpdates.ts`
  - Functions: `listProgressUpdates`, `createProgressUpdate`, `deleteProgressUpdate`

### Types
- New type: `ProgressUpdate` in `src/types.ts`

## How to Use

### For Assignees

1. **Update Your Progress**:
   - Go to "Structure" page or "My Jobs" page
   - Find an activity assigned to you
   - Click "Update Progress" button
   - Enter new progress %, select status, add optional notes
   - Click "Save Update"

2. **View Progress History**:
   - Click "View Progress History" on any activity
   - See all past updates with who made them and when
   - Each update shows: status, progress %, reporter, timestamp, and notes

### Security
- Only the person assigned to an activity can see the "Update Progress" button
- All authenticated users can view progress history
- All progress updates are tracked (full audit trail)

## Database Setup

**IMPORTANT**: You need to run the updated schema in Supabase:

1. Go to your Supabase Dashboard → SQL Editor
2. Copy the contents of `supabase/schema.sql`
3. Run it (this will add the `progress_updates` table and policies)
4. The table will be created safely (won't duplicate if it exists)

## Features

- **Full History**: Every progress update is saved
- **Audit Trail**: Who updated, when, and what they changed
- **Notes**: Optional notes with each update
- **Status Tracking**: Track status changes over time
- **Progress Tracking**: See progress % changes over time
- **Auto-Show History**: History automatically shows after you submit an update

## Workflow Example

1. Create activity with 0% progress
2. Start working → Update to 25% with note "Initial research complete"
3. Halfway done → Update to 50% with note "Core functionality implemented"
4. Blocked → Update to 50% blocked status with note "Waiting on API access"
5. Done → Update to 100% done with note "Shipped to production!"

All of these updates are saved and visible in the progress history!

