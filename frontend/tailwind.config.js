/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      colors: {
        brand: {
          50:  '#eef4ff',
          100: '#dbe6ff',
          200: '#bfd1ff',
          300: '#93b1ff',
          400: '#6086ff',
          500: '#3b5fff',
          600: '#2540f5',
          700: '#1d31d8',
          800: '#1c2bae',
          900: '#1d2a89',
        },
      },
      boxShadow: {
        card: '0 1px 2px rgba(15, 23, 42, 0.04), 0 4px 16px rgba(15, 23, 42, 0.06)',
        cardHover: '0 8px 28px rgba(15, 23, 42, 0.12)',
        // Las tarjetas del tablero van sobre una foto del juego, no sobre un
        // fondo plano: necesitan una sombra mas marcada para despegarse.
        tarjeta:
          '0 1px 2px rgba(15, 23, 42, 0.06), 0 4px 10px rgba(15, 23, 42, 0.08), 0 12px 28px rgba(15, 23, 42, 0.10)',
        tarjetaHover:
          '0 2px 4px rgba(15, 23, 42, 0.08), 0 10px 20px rgba(15, 23, 42, 0.12), 0 24px 48px rgba(29, 42, 137, 0.18)',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: 0, transform: 'translateY(6px)' },
          '100%': { opacity: 1, transform: 'translateY(0)' },
        },
      },
      animation: {
        fadeIn: 'fadeIn .25s ease-out both',
      },
    },
  },
  plugins: [],
};
