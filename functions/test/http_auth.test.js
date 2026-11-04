// Testes do middleware das rotas HTTP (auditoria A14). Rodam sobre o código compilado:
//   cd functions && npm run build && node --test test/
const { test } = require('node:test');
const assert = require('node:assert');
const { requireActiveStaff, cleanText, cleanInt } = require('../lib/http_auth');

const profiles = {
  admin: { role: 'admin', isActive: true },
  estoquista: { role: 'estoquista', isActive: true },
  voluntario: { role: 'voluntario', isActive: true },
  doador: { role: 'doador', isActive: true },
  inativo: { role: 'admin', isActive: false },
};

const mw = requireActiveStaff({
  verifyToken: async (t) => {
    if (!t.startsWith('ok-')) throw new Error('token inválido');
    return { uid: t.slice(3) };
  },
  loadProfile: async (uid) => profiles[uid],
});

async function call(authorization) {
  const res = {
    statusCode: 200,
    body: null,
    locals: {},
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
  let nextCalled = false;
  await mw({ header: () => authorization }, res, () => { nextCalled = true; });
  return { res, nextCalled };
}

test('sem token: 401 e não grava', async () => {
  const { res, nextCalled } = await call(undefined);
  assert.equal(res.statusCode, 401);
  assert.equal(nextCalled, false);
});

test('token inválido: 401', async () => {
  const { res, nextCalled } = await call('Bearer forjado');
  assert.equal(res.statusCode, 401);
  assert.equal(nextCalled, false);
});

for (const uid of ['voluntario', 'doador', 'inativo', 'desconhecido']) {
  test(`${uid}: 403`, async () => {
    const { res, nextCalled } = await call(`Bearer ok-${uid}`);
    assert.equal(res.statusCode, 403);
    assert.equal(nextCalled, false);
  });
}

for (const uid of ['admin', 'estoquista']) {
  test(`${uid} ativo: segue e registra o uid`, async () => {
    const { res, nextCalled } = await call(`Bearer ok-${uid}`);
    assert.equal(nextCalled, true);
    assert.equal(res.locals.uid, uid);
  });
}

test('validação de entrada', () => {
  assert.equal(cleanText('  Arroz  '), 'Arroz');
  assert.equal(cleanText(''), null);
  assert.equal(cleanText(42), null);
  assert.equal(cleanText('x'.repeat(201)), null);
  assert.equal(cleanInt(3), 3);
  assert.equal(cleanInt(-1), null);
  assert.equal(cleanInt(1.5), null);
  assert.equal(cleanInt('3'), null);
});
