import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true, // Crucial for Docker container communication
    proxy: {
      // Forwards /api/v1/... requests seamlessly to the backend target
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        secure: false, // Prevents failure with self-signed dev certificates
        configure: (proxy, _options) => {
          proxy.on('error', (err, _req, _res) => {
            console.error('Vite Proxy Gateway Error:', err);
          });
        }
      }
    }
  }
})
