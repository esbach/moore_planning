<script setup lang="ts">
defineProps<{ 
  open: boolean;
  size?: 'sm' | 'md' | 'lg' | 'xl' | '2xl' | 'full' | 'half';
}>();
defineEmits<{ (e: 'close'): void }>();

const sizeClasses = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  '2xl': 'max-w-2xl',
  full: 'max-w-7xl',
  half: 'max-w-[50vw]',
};
</script>

<template>
  <div v-if="open" class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="absolute inset-0 bg-black/40" @click="$emit('close')"></div>
    <div 
      class="relative bg-white rounded shadow-lg w-full p-4"
      :class="sizeClasses[size || 'lg']"
      @click.stop
    >
      <slot />
    </div>
  </div>
  
</template>


