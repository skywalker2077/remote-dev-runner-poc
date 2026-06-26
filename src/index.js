const express = require('express');
const { name, version } = require('../package.json');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/version', (_req, res) => {
  res.json({ name, version });
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`${name}@${version} listening on port ${PORT}`);
  });
}

module.exports = app;
