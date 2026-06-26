const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;
const VERSION = process.env.npm_package_version || '1.0.0';

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/version', (req, res) => {
  res.json({ version: VERSION, env: process.env.NODE_ENV || 'development' });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`remote-dev-runner-poc listening on port ${PORT}`);
  });
}

module.exports = app;
