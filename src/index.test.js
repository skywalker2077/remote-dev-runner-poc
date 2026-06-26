const request = require('supertest');
const app = require('./index');
const { name, version } = require('../package.json');

describe('GET /health', () => {
  it('returns status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('GET /version', () => {
  it('returns package name and version', async () => {
    const res = await request(app).get('/version');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe(name);
    expect(res.body.version).toBe(version);
  });
});
