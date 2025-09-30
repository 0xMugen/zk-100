/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'zk-bg': '#0a0a0a',
        'zk-node': '#1a1a1a',
        'zk-border': '#333',
        'zk-accent': '#00ff88',
        'zk-error': '#ff0055',
      },
      fontFamily: {
        'mono': ['JetBrains Mono', 'Consolas', 'monospace'],
      },
    },
  },
  plugins: [],
}