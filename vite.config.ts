import { defineConfig } from 'vite';

// Proxy de dev pra contornar o CORS da pokemontcg.io no browser.
// Em produção isso vira um backend/edge function (Supabase) fazendo o mesmo.
export default defineConfig({
  server: {
    host: true, // escuta em 0.0.0.0 — acessível pela rede local (celular etc.)
    proxy: {
      '/pokeapi': {
        target: 'https://api.pokemontcg.io',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/pokeapi/, ''),
      },
      '/tcgdex': {
        target: 'https://api.tcgdex.net',
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/tcgdex/, ''),
      },
    },
  },
});
