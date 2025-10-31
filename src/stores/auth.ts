import { defineStore } from 'pinia';
import { supabase } from '@/lib/supabaseClient';
import type { Profile } from '@/types';

export const useAuthStore = defineStore('auth', {
  state: () => ({
    session: null as any,
    profile: null as Profile | null,
    loading: false,
  }),
  actions: {
    async init() {
      const { data } = await supabase.auth.getSession();
      this.session = data.session;
      supabase.auth.onAuthStateChange((_e, s) => { this.session = s; if (s) { this.fetchOrCreateProfile(); } else { this.profile = null; } });
      if (this.session) await this.fetchOrCreateProfile();
    },
    async signInWithEmail(email: string) {
      this.loading = true;
      try {
        await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: window.location.origin } });
      } finally {
        this.loading = false;
      }
    },
    async signOut() { 
      await supabase.auth.signOut();
      this.session = null;
      this.profile = null;
    },
    async fetchOrCreateProfile() {
      const user = this.session?.user;
      if (!user) return;
      const { data } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
      if (data) { this.profile = data as Profile; return; }
      const insert = { id: user.id, full_name: user.user_metadata?.full_name ?? null, email: user.email };
      const { data: created } = await supabase.from('profiles').insert(insert).select('*').single();
      this.profile = created as Profile;
    },
  },
});


