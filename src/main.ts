import { createApp } from 'vue';
import { createPinia } from 'pinia';
import AuthGate from '@/components/AuthGate.vue';
import router from '@/router';
import './styles.css';

const app = createApp(AuthGate);
app.use(createPinia());
app.use(router);
app.mount('#app');


