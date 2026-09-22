// Production server for the built dashboard (used on Railway via `npm start`).
// Serves dist/ on $PORT and falls back to index.html so client-side routes
// like /cases/:id work on a hard refresh.
import http from 'node:http';
import handler from 'serve-handler';

const port = Number(process.env.PORT) || 4000;

http
  .createServer((req, res) =>
    handler(req, res, {
      public: 'dist',
      rewrites: [{ source: '**', destination: '/index.html' }],
    }),
  )
  .listen(port, '0.0.0.0', () => console.log(`Admin dashboard served on port ${port}`));
