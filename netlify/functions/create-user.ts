import { Handler } from '@netlify/functions';
import { createClient } from '@supabase/supabase-js';

export const handler: Handler = async (event) => {
  // Only allow POST requests
  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  try {
    // Get environment variables
    const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseServiceKey) {
      return {
        statusCode: 500,
        body: JSON.stringify({ 
          error: 'Server configuration error: Missing Supabase credentials' 
        }),
      };
    }

    // Parse request body
    const body = JSON.parse(event.body || '{}');
    const { email, password, full_name, is_admin, project_id, project_role } = body;

    if (!email || !password) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Email and password are required' }),
      };
    }

    if (password.length < 6) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Password must be at least 6 characters' }),
      };
    }

    // Create Supabase admin client (uses service role key for admin operations)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Create user in Supabase Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Auto-confirm email so they can login immediately
      user_metadata: {
        full_name: full_name || null,
      },
    });

    if (authError) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: authError.message }),
      };
    }

    if (!authData.user) {
      return {
        statusCode: 500,
        body: JSON.stringify({ error: 'User creation failed' }),
      };
    }

    // Create profile
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert({
        id: authData.user.id,
        email,
        full_name: full_name || null,
        is_admin: is_admin || false,
      });

    if (profileError) {
      // If profile creation fails, try to delete the auth user
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id);
      return {
        statusCode: 400,
        body: JSON.stringify({ error: profileError.message }),
      };
    }

    // If a project is selected, assign user to it
    if (project_id && project_role) {
      const { error: assignError } = await supabaseAdmin
        .from('project_users')
        .insert({
          project_id,
          user_id: authData.user.id,
          role: project_role,
        });

      if (assignError) {
        console.warn('Failed to assign user to project:', assignError);
        // Don't fail the whole operation if assignment fails
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ 
        success: true,
        user_id: authData.user.id,
        email: authData.user.email,
      }),
    };
  } catch (error: any) {
    console.error('Error creating user:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message || 'Internal server error' }),
    };
  }
};

