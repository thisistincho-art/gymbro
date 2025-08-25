/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        // Asegúrate de que 'Inter' sea la primera opción o la única si quieres forzarla
        inter: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
