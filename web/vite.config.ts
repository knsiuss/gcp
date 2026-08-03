import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base './' -> works when hosted on GitHub Pages at /gcp/ or any sub-path
export default defineConfig({
  base: './',
  plugins: [react()],
})
