<script setup lang="ts">
defineProps<{ open: boolean }>();
defineEmits<{ (e: 'close'): void }>();
</script>

<template>
  <div v-if="open" class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/40" @click="$emit('close')"></div>
    <div class="relative bg-white rounded shadow-lg w-full max-w-lg p-4">
      <slot />
    </div>
  </div>
  
</template>


