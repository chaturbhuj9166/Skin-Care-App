const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { initSocket } = require('./services/socket');

const server = http.createServer(app);

initSocket(server);

server.listen(env.PORT, () => {
  console.log(`SkinCare Consultation API listening on port ${env.PORT} [${env.NODE_ENV}]`);
});

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled promise rejection:', reason);
});

module.exports = server;
