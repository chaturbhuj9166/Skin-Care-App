/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        teal: { DEFAULT: '#0A7C6E', 50: '#E6F3F1', 100: '#CCE7E3', 500: '#0A7C6E', 600: '#086459', 700: '#064B43' },
        brand: {
          teal: '#0A7C6E',
          green: '#22C55E',
          amber: '#F59E0B',
        },
      },
      fontFamily: {
        heading: ['Poppins', 'sans-serif'],
        body: ['Inter', 'sans-serif'],
      },
      borderRadius: {
        card: '12px',
        btn: '8px',
      },
    },
  },
  plugins: [],
}
