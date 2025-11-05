# Setting Up User Creation Feature

You have two options for creating users. **Option 2 (Edge Functions) is recommended** as it's simpler and doesn't require managing service role keys.

## Option 2: Using Supabase Edge Functions (Recommended - Simpler!)

### Step 1: Deploy the Edge Function

The Edge Function is already created at `supabase/functions/create-user/index.ts`. To deploy it:

1. **If you have Supabase CLI installed:**
   ```bash
   supabase functions deploy create-user
   ```

2. **Or use the Supabase Dashboard:**
   - Go to your [Supabase Dashboard](https://supabase.com/dashboard)
   - Select your project
   - Go to **Edge Functions** in the left sidebar
   - Click **Create a new function**
   - Name it `create-user`
   - Copy and paste the contents of `supabase/functions/create-user/index.ts`
   - Click **Deploy**

### Step 2: Test

1. Log in as an admin
2. Click "User Management" in the sidebar
3. Try creating a new user

That's it! No service role keys needed - Edge Functions have automatic access to the Admin API.

---

## Option 1: Using Netlify Functions (Alternative)

If you prefer to use Netlify Functions instead:

### Step 1: Get Your Service Role Key

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** → **API**
4. Scroll down to find **Service Role Key** (NOT the anon key)
5. Copy this key (it starts with `eyJ...`)

⚠️ **Important**: The Service Role Key has admin privileges. Never expose it in client-side code or commit it to git.

### Step 2: Add to Netlify Environment Variables

1. Go to your [Netlify Dashboard](https://app.netlify.com)
2. Select your site
3. Go to **Site settings** → **Environment variables**
4. Click **Add a variable**
5. Add these variables:
   - **Key**: `SUPABASE_SERVICE_ROLE_KEY`
   - **Value**: (paste your service role key from Step 1)
   - **Scopes**: Select **All scopes**

6. (Optional) If `VITE_SUPABASE_URL` isn't already set, add it:
   - **Key**: `VITE_SUPABASE_URL`
   - **Value**: `https://ezlykhqipefwyxvpugzb.supabase.co`

### Step 3: Update the Code

If using Netlify Functions, you'll need to change the fetch URL in `src/components/admin/UserManager.vue` back to:
```typescript
const response = await fetch('/.netlify/functions/create-user', {
```

---

## Which Option Should I Use?

**Use Edge Functions (Option 2)** if:
- ✅ You want the simplest setup (no service role keys to manage)
- ✅ You're already using Supabase
- ✅ You want automatic Admin API access

**Use Netlify Functions (Option 1)** if:
- ✅ You're already using Netlify Functions for other features
- ✅ You prefer all serverless functions in one place

---

## Troubleshooting

### Error: "Failed to create user. Make sure the Supabase Edge Function is deployed."

Make sure you've deployed the Edge Function. Check the Supabase Dashboard → Edge Functions to see if `create-user` is listed.

### Error: "Forbidden: Admin access required"

Make sure you're logged in as a user with `is_admin = true` in the profiles table.

### Error: "Unauthorized"

Make sure you're logged in. The Edge Function requires authentication.

### Testing Locally with Edge Functions

If you have Supabase CLI:
```bash
supabase functions serve create-user
```

Then update the fetch URL in development to point to `http://localhost:54321/functions/v1/create-user`

---

## Security Notes

- Edge Functions automatically have access to the Admin API
- The function checks that the requesting user is an admin before creating users
- Never expose service role keys in client-side code
- The function validates admin status before allowing user creation
