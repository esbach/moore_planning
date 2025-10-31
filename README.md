# Coordination App

A Vue 3 application for managing activities, outcomes, objectives, and outputs with Supabase backend.

## Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- Supabase account

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Go to Dashboard → Settings → API
3. Copy your project URL and anon key

### 3. Set Up Environment Variables

Create a `.env` file in the project root:

```env
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
```

### 4. Set Up Database Schema

1. In Supabase Dashboard → SQL Editor
2. Paste and run the contents of `supabase/schema.sql`
3. Confirm tables are created: `outcomes`, `objectives`, `outputs`, `activities`, `profiles`

### 5. Enable Authentication

In Supabase Dashboard → Authentication → Providers → Email:
- Enable email authentication
- Optionally enable magic link authentication

### 6. Run the App

```bash
npm run dev
```

The app will be available at `http://localhost:5173`

## Features

- **Outcomes**: Top-level goals for your project
- **Objectives**: Break down outcomes into specific objectives
- **Outputs**: Create outputs for each objective
- **Activities**: Track individual activities within outputs
- **Calendar View**: Visualize activities on a calendar
- **Authentication**: Secure user authentication with Supabase

## Usage

1. Sign up or sign in with your email
2. Click "+ Add outcome" to create your first outcome
3. Add objectives, outputs, and activities as needed
4. Use the calendar view to manage activity timelines

## Project Structure

- `src/components/hierarchy/` - Hierarchy tree components for outcomes/objectives/outputs
- `src/components/calendar/` - Calendar view component
- `src/api/` - API functions for Supabase operations
- `src/stores/` - Pinia stores for state management
- `supabase/` - Database schema and setup instructions

## Development

```bash
# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Troubleshooting

- If buttons don't work, check that environment variables are set correctly
- If database operations fail, verify the schema has been applied in Supabase
- Check browser console for error messages

## Deployment

### Deploying to Netlify

This app is configured for easy deployment to Netlify:

1. **Push to GitHub**
   ```bash
   # Initialize git repository (if not already done)
   git init
   git add .
   git commit -m "Initial commit"
   
   # Create a new repository on GitHub, then:
   git remote add origin https://github.com/yourusername/your-repo-name.git
   git branch -M main
   git push -u origin main
   ```

2. **Connect to Netlify**
   - Go to [netlify.com](https://netlify.com) and sign in
   - Click "Add new site" → "Import an existing project"
   - Connect your GitHub account and select your repository
   - Netlify will detect the `netlify.toml` configuration automatically

3. **Configure Environment Variables**
   - In Netlify Dashboard → Site settings → Environment variables
   - Add the following variables:
     - `VITE_SUPABASE_URL`: Your Supabase project URL
     - `VITE_SUPABASE_ANON_KEY`: Your Supabase anon key
   - Redeploy after adding environment variables

4. **Deploy**
   - Netlify will automatically deploy on every push to your main branch
   - Or trigger a manual deploy from the Deploys tab

Your app will be live at a Netlify URL (e.g., `your-app-name.netlify.app`)

**Note**: Make sure your Supabase project allows connections from your Netlify domain. You may need to update CORS settings or authentication redirect URLs in Supabase Dashboard → Authentication → URL Configuration.

