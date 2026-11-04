// Auditoria A05: os gatilhos de doação podem ser entregues mais de uma vez e fora de
// ordem. Estes testes chamam os gatilhos de verdade (`.run`) contra o Firestore do
// EMULADOR (projeto demo-, sem acesso à base real), repetindo o mesmo evento.
//
//   cd functions && npm run build
//   firebase emulators:exec --only firestore --project demo-educastock \
//     "node --test functions/test/donations.emulator.test.js"
const { test, beforeEach } = require('node:test');
const assert = require('node:assert');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Rode com o emulador (firebase emulators:exec); nunca contra a base real.');
}
const admin = require('firebase-admin');
const { onDonationCreated, onDonationStatusChanged } = require('../lib/donations');
const db = admin.firestore();

async function clear() {
  for (const col of ['donations', 'donation_needs', 'settings', 'alerts', 'audit_logs', 'user_notifications']) {
    const snap = await db.collection(col).get();
    await Promise.all(snap.docs.map((d) => db.recursiveDelete(d.ref)));
  }
}

beforeEach(async () => {
  await clear();
  await db.doc('donation_needs/leite').set({ suggestedQty: 100, pledgedQty: 0, remainingQty: 100 });
});

async function createDonation(id, extra = {}) {
  await db.doc(`donations/${id}`).set({
    donorId: 'doador-1',
    donorSnapshot: { displayName: 'Ana' },
    status: 'pendente',
    items: [{ description: 'Leite', quantity: 10, needId: 'leite' }],
    ...extra,
  });
  return db.doc(`donations/${id}`).get();
}

test('criação entregue duas vezes: um protocolo, uma reserva, um evento, um alerta', async () => {
  const snap = await createDonation('d1');
  const event = { id: 'evt-criacao-1', data: snap, params: { donationId: 'd1' } };
  await onDonationCreated.run(event);
  await onDonationCreated.run(event); // entrega repetida (snapshot antigo, sem protocolo)

  const d = (await db.doc('donations/d1').get()).data();
  assert.match(d.protocol, /^DOA-\d{4}-000001$/);
  const counters = (await db.doc('settings/counters').get()).data();
  assert.equal(Object.values(counters)[0], 1, 'contador incrementado uma vez');
  assert.equal((await db.doc('donation_needs/leite').get()).data().pledgedQty, 10, 'reserva única');
  assert.equal((await db.collection('donations/d1/events').get()).size, 1);
  assert.equal((await db.collection('alerts').get()).size, 1);
});

test('cancelamento entregue duas vezes devolve a reserva uma vez só e avisa uma vez', async () => {
  const created = await createDonation('d2');
  await onDonationCreated.run({ id: 'evt-c2', data: created, params: { donationId: 'd2' } });
  const before = await db.doc('donations/d2').get();
  await db.doc('donations/d2').update({ status: 'cancelada', cancelReason: 'teste' });
  const after = await db.doc('donations/d2').get();

  const event = { id: 'evt-cancel-2', data: { before, after }, params: { donationId: 'd2' } };
  await onDonationStatusChanged.run(event);
  await onDonationStatusChanged.run(event); // repetido

  assert.equal((await db.doc('donation_needs/leite').get()).data().pledgedQty, 0, 'devolvida uma vez');
  assert.equal((await db.doc('donations/d2').get()).data().reservationReleased, true);
  const events = await db.collection('donations/d2/events').get();
  assert.equal(events.docs.filter((e) => e.data().type === 'status_changed').length, 1);
  const notes = await db.collection('user_notifications/doador-1/items').get();
  assert.equal(notes.size, 1, 'um aviso ao doador');
  assert.equal((await db.collection('audit_logs').get()).size, 1);
});

test('evento atrasado de transição inválida não desfaz um status mais novo', async () => {
  const created = await createDonation('d3');
  await onDonationCreated.run({ id: 'evt-c3', data: created, params: { donationId: 'd3' } });
  // Evento antigo: pendente -> recebida (inválida), mas o documento já está em "aprovada".
  const before = await db.doc('donations/d3').get();
  await db.doc('donations/d3').update({ status: 'recebida' });
  const after = await db.doc('donations/d3').get();
  await db.doc('donations/d3').update({ status: 'aprovada' }); // estado atual mais novo

  await onDonationStatusChanged.run({ id: 'evt-velho', data: { before, after }, params: { donationId: 'd3' } });
  assert.equal((await db.doc('donations/d3').get()).data().status, 'aprovada', 'não foi revertido');
});

test('transição inválida ainda atual é revertida (comportamento preservado)', async () => {
  const created = await createDonation('d4');
  await onDonationCreated.run({ id: 'evt-c4', data: created, params: { donationId: 'd4' } });
  const before = await db.doc('donations/d4').get();
  await db.doc('donations/d4').update({ status: 'recebida' });
  const after = await db.doc('donations/d4').get();

  await onDonationStatusChanged.run({ id: 'evt-inv', data: { before, after }, params: { donationId: 'd4' } });
  assert.equal((await db.doc('donations/d4').get()).data().status, 'pendente');
});
