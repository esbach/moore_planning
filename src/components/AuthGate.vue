<script setup lang="ts">
import { onMounted, computed, ref } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { supabase } from '@/lib/supabaseClient';
import AppLayout from '@/components/layout/AppLayout.vue';

const auth = useAuthStore();
const email = ref('');
const password = ref('');
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
</script>

<template>
  <div class="h-full">
    <div v-if="!isAuthed" class="h-full grid place-items-center p-6">
      <div class="w-full max-w-sm space-y-4">
        <h1 class="text-xl font-semibold">Sign in</h1>
        <div class="space-y-3">
          <input v-model="email" type="email" placeholder="Email" class="w-full border rounded px-3 py-2" />
          <input v-model="password" type="password" placeholder="Password" class="w-full border rounded px-3 py-2" />
          <button @click="signInPassword" class="w-full bg-blue-600 text-white rounded px-3 py-2">Sign in</button>
        </div>
        <p v-if="errorMsg" class="text-sm text-red-600">{{ errorMsg }}</p>
        <p class="text-xs text-gray-500 text-center mt-4">
          Need an account? Contact your administrator to receive login credentials.
        </p>
      </div>
    </div>
    <div v-else class="h-full">
      <RouterView />
    </div>
  </div>
  
</template>


