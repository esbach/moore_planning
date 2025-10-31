# Supabase Setup

1) Enable Email Auth
- In Supabase Dashboard → Authentication → Providers → Email: enable (magic links optional).

2) Apply Schema
- Open SQL editor, paste and run `schema.sql` from this folder.
- Confirm tables: `outcomes`, `objectives`, `outputs`, `activities`, `profiles`, `progress_updates`.
- Confirm RLS enabled and policies created.

**OR if you already have the schema applied:**
- Run the `add_progress_updates.sql` migration file to add just the progress_updates table.

3) Storage (optional)
- The schema inserts a `links` public bucket if storage is enabled.

4) Create your first profile (optional)
- After first login, the app will upsert a `profiles` row. You can also insert manually:
```sql
insert into public.profiles (id, full_name, email)
values ('<auth.users.id>', 'Michael Esbach', 'michael.s.esbach@gmail.com');
```

5) Gather ENV
- Copy your project URL and anon key from Dashboard → Settings → API.
- Create `.env` in the app root with:
```
VITE_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
