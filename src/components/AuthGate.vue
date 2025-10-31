<script setup lang="ts">
import { onMounted, computed, ref } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/lib/supabaseClient';
import AppLayout from '@/components/layout/AppLayout.vue';

const auth = useAuthStore();
const mode = ref<'magic' | 'password' | 'signup'>('password');
const email = ref('');
const password = ref('');
const fullName = ref('');
const errorMsg = ref('');

onMounted(() => auth.init());

const isAuthed = computed(() => !!auth.session);

async function signInPassword() {
  errorMsg.value = '';
  try {
    const { error } = await supabase.auth.signInWithPassword({ email: email.value, password: password.value });
    if (error) throw error;
  } catch (e: any) {
    errorMsg.value = e?.message || 'Sign-in failed';
  }
}

async function signUpPassword() {
  errorMsg.value = '';
  try {
    const { data, error } = await supabase.auth.signUp({
      email: email.value,
      password: password.value,
      options: { data: { full_name: fullName.value || null } },
    });
    if (error) throw error;
    // If email confirmation is enabled, user may need to confirm via email
  } catch (e: any) {
    errorMsg.value = e?.message || 'Sign-up failed';
  }
}
</script>

<template>
  <div class="h-full">
    <div v-if="!isAuthed" class="h-full grid place-items-center p-6">
      <div class="w-full max-w-sm space-y-4">
        <h1 class="text-xl font-semibold">Sign in</h1>
        <div class="flex gap-2 text-sm">
          <button class="underline" :class="{ 'font-semibold': mode==='password' }" @click="mode='password'">Password</button>
          <button class="underline" :class="{ 'font-semibold': mode==='magic' }" @click="mode='magic'">Magic link</button>
          <button class="underline" :class="{ 'font-semibold': mode==='signup' }" @click="mode='signup'">Sign up</button>
        </div>
        <div v-if="mode==='password'" class="space-y-3">
          <input v-model="email" type="email" placeholder="Email" class="w-full border rounded px-3 py-2" />
          <input v-model="password" type="password" placeholder="Password" class="w-full border rounded px-3 py-2" />
          <button @click="signInPassword" class="w-full bg-blue-600 text-white rounded px-3 py-2">Sign in</button>
        </div>
        <div v-else-if="mode==='magic'" class="space-y-3">
          <input v-model="email" type="email" placeholder="Email" class="w-full border rounded px-3 py-2" />
          <button :disabled="auth.loading" @click="auth.signInWithEmail(email)" class="w-full bg-blue-600 text-white rounded px-3 py-2">
            Send magic link
          </button>
          <p class="text-sm text-gray-600">Check your email for a login link.</p>
        </div>
        <div v-else class="space-y-3">
          <input v-model="fullName" type="text" placeholder="Full name (optional)" class="w-full border rounded px-3 py-2" />
          <input v-model="email" type="email" placeholder="Email" class="w-full border rounded px-3 py-2" />
          <input v-model="password" type="password" placeholder="Password" class="w-full border rounded px-3 py-2" />
          <button @click="signUpPassword" class="w-full bg-green-600 text-white rounded px-3 py-2">Create account</button>
        </div>
        <p v-if="errorMsg" class="text-sm text-red-600">{{ errorMsg }}</p>
      </div>
    </div>
    <div v-else class="h-full">
      <RouterView />
    </div>
  </div>
  
</template>


