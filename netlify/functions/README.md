# Netlify Functions Setup

This directory contains serverless functions for admin operations that require Supabase Admin API access.

## Required Environment Variables

To use the `create-user` function, you need to set up the following environment variables in your Netlify dashboard:

1. **VITE_SUPABASE_URL** (or **SUPABASE_URL**) - Your Supabase project URL
2. **SUPABASE_SERVICE_ROLE_KEY** - Your Supabase service role key (found in Supabase Dashboard → Settings → API → Service Role Key)

⚠️ **Important**: The service role key has admin privileges. Never expose it in client-side code or commit it to version control.

## Setup Instructions

1. Go to your Netlify project dashboard
2. Navigate to **Site settings** → **Environment variables**
3. Add the following variables:
   - `VITE_SUPABASE_URL` = `https://your-project.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = `your-service-role-key`

## Functions

### `create-user`

Creates a new user account with email/password authentication.

**Endpoint**: `POST /.netlify/functions/create-user`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "full_name": "John Doe",
  "is_admin": false,
  "project_id": "optional-project-uuid",
  "project_role": "viewer"
}
```

**Response**:
```json
{
  "success": true,
  "user_id": "uuid",
  "email": "user@example.com"
}
```

