// Regra de validade da função de alertas = regra do app (dia civil, fuso de São Paulo).
//   cd functions && npm run build && node --test test/alerts.test.js
const { test } = require('node:test');
const assert = require('node:assert');
const { daysUntil } = require('../lib/alerts');

test('vence hoje = 0 o dia inteiro (no fuso de São Paulo)', () => {
  // 10/11 às 23h30 em São Paulo = 11/11 02:30 UTC
  assert.equal(daysUntil('2026-11-10T00:00:00.000', new Date('2026-11-11T02:30:00Z')), 0);
  // 10/11 às 08h em São Paulo
  assert.equal(daysUntil('2026-11-10T00:00:00.000', new Date('2026-11-10T11:00:00Z')), 0);
});

test('amanhã = 1, mesmo faltando poucas horas para a meia-noite', () => {
  assert.equal(daysUntil('2026-11-10T00:00:00.000', new Date('2026-11-10T02:00:00Z')), 1); // 09/11 23h SP
});

test('dia seguinte = vencido (-1)', () => {
  assert.equal(daysUntil('2026-11-10T00:00:00.000', new Date('2026-11-11T04:00:00Z')), -1); // 11/11 01h SP
});
