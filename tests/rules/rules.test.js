// Testes das regras do Firestore e do Storage no EMULADOR.
//
// Usa o projeto "demo-educastock": projetos "demo-" não existem na nuvem, então estes
// testes não conseguem ler nem gravar a base real (isolamento garantido pelo emulador).
//
// Rodar (na raiz do repositório):
//   firebase emulators:exec --only firestore,storage --project demo-educastock "npm --prefix tests/rules test"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

const PROJECT = 'demo-educastock';
const root = new URL('../../', import.meta.url);
let env;

const USERS = {
  admin: { role: 'admin', isActive: true },
  estoquista: { role: 'estoquista', isActive: true },
  voluntario: { role: 'voluntario', isActive: true },
  consulta: { role: 'consulta', isActive: true },
  doador: { role: 'doador', isActive: true },
  adminInativo: { role: 'admin', isActive: false },
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: readFileSync(new URL('firestore.rules', root), 'utf8') },
    storage: { rules: readFileSync(new URL('storage.rules', root), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, data] of Object.entries(USERS)) {
      await setDoc(doc(db, 'users', uid), { name: uid, email: `${uid}@teste.test`, ...data });
    }
    await setDoc(doc(db, 'products', 'p1'), { name: 'Arroz', isActive: true, category: 'alimento' });
    await setDoc(doc(db, 'batches', 'b1'), {
      productId: 'p1', productName: 'Arroz', quantity: 10, status: 'disponivel', noExpiry: false,
      expiryDate: '2026-12-01T00:00:00.000',
    });
    await setDoc(doc(db, 'stock_movements', 'm1'), {
      productId: 'p1', type: 'saida', quantity: 2, performedAt: '2026-11-01T10:00:00.000',
    });
    await setDoc(doc(db, 'consumption_forecasts', 'p1'), { productId: 'p1', trend: 'stable' });
    await setDoc(doc(db, 'risk_classifications', 'b1'), { batchId: 'b1', level: 'verde' });
    await setDoc(doc(db, 'settings', 'alerts'), { expiryEnabled: true });
    await setDoc(doc(db, 'donations', 'd-pendente'), {
      donorId: 'doador', status: 'pendente', items: [{ description: 'Arroz', quantity: 5 }],
    });
    await setDoc(doc(db, 'donations', 'd-protocolada'), {
      donorId: 'doador', status: 'aprovada', protocol: 'DOA-2026-000001',
      items: [{ description: 'Arroz', quantity: 5 }],
    });
  });
});

const db = (uid, token = {}) => env.authenticatedContext(uid, token).firestore();

describe('Relatórios: leituras da aba Gráficos (diagnóstico do permission-denied)', () => {
  for (const role of ['admin', 'estoquista', 'voluntario', 'consulta']) {
    test(`${role} ativo lê lotes, produtos, movimentações, previsões, risco e configurações`, async () => {
      const d = db(role);
      await assertSucceeds(getDocs(query(collection(d, 'batches'),
        where('status', '==', 'disponivel'), where('quantity', '>', 0))));
      await assertSucceeds(getDocs(query(collection(d, 'products'), where('isActive', '==', true))));
      await assertSucceeds(getDocs(query(collection(d, 'stock_movements'),
        where('performedAt', '>=', '2026-10-01T00:00:00.000'))));
      await assertSucceeds(getDocs(collection(d, 'consumption_forecasts')));
      await assertSucceeds(getDocs(collection(d, 'risk_classifications')));
      await assertSucceeds(getDoc(doc(d, 'settings', 'alerts')));
    });
  }

  test('doador não lê lotes nem movimentações', async () => {
    await assertFails(getDocs(collection(db('doador'), 'batches')));
    await assertFails(getDocs(collection(db('doador'), 'stock_movements')));
  });

  test('administrador DESATIVADO não lê o estoque', async () => {
    await assertFails(getDocs(collection(db('adminInativo'), 'batches')));
  });
});

describe('A04 — conta desativada não exerce poderes administrativos', () => {
  test('admin desativado não reativa o próprio perfil', async () => {
    await assertFails(updateDoc(doc(db('adminInativo'), 'users', 'adminInativo'), { isActive: true }));
  });

  test('admin desativado não altera papel de outra pessoa', async () => {
    await assertFails(updateDoc(doc(db('adminInativo'), 'users', 'voluntario'), { role: 'admin' }));
  });

  test('admin desativado não apaga produto', async () => {
    await assertFails(deleteDoc(doc(db('adminInativo'), 'products', 'p1')));
  });

  test('admin ativo continua administrando usuários e produtos', async () => {
    await assertSucceeds(updateDoc(doc(db('admin'), 'users', 'voluntario'), { isActive: false }));
    await assertSucceeds(deleteDoc(doc(db('admin'), 'products', 'p1')));
  });

  test('ninguém altera o próprio papel', async () => {
    await assertFails(updateDoc(doc(db('voluntario'), 'users', 'voluntario'), { role: 'admin' }));
  });
});

describe('A06 — campos internos de doação', () => {
  const valid = () => ({
    donorId: 'doador',
    donorSnapshot: { displayName: 'Doador' },
    status: 'pendente',
    items: [{ description: 'Arroz', quantity: 5 }],
    pointId: 'sede',
    window: null,
    termsAcceptedAt: serverTimestamp(),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  const donor = () => db('doador', { email_verified: true });

  test('doador cria doação com os campos do formulário', async () => {
    await assertSucceeds(setDoc(doc(donor(), 'donations', 'nova'), valid()));
  });

  test('doador não envia protocolo próprio', async () => {
    await assertFails(setDoc(doc(donor(), 'donations', 'nova'), { ...valid(), protocol: 'DOA-2026-999999' }));
  });

  test('doador não envia marcador de processamento', async () => {
    await assertFails(setDoc(doc(donor(), 'donations', 'nova'),
      { ...valid(), clientProcessedStatus: 'aprovada' }));
  });

  test('doador não cria doação já aprovada nem em nome de outra pessoa', async () => {
    await assertFails(setDoc(doc(donor(), 'donations', 'nova'), { ...valid(), status: 'aprovada' }));
    await assertFails(setDoc(doc(donor(), 'donations', 'nova'), { ...valid(), donorId: 'outra' }));
  });

  test('doador cancela a própria doação pendente', async () => {
    await assertSucceeds(updateDoc(doc(donor(), 'donations', 'd-pendente'),
      { status: 'cancelada', cancelReason: 'Não consigo levar', updatedAt: serverTimestamp() }));
  });

  test('equipe aprova e define o protocolo quando ainda não existe', async () => {
    await assertSucceeds(updateDoc(doc(db('estoquista'), 'donations', 'd-pendente'),
      { status: 'aprovada', protocol: 'DOA-2026-000002' }));
  });

  test('equipe não reescreve protocolo já emitido', async () => {
    await assertFails(updateDoc(doc(db('estoquista'), 'donations', 'd-protocolada'),
      { protocol: 'DOA-2026-000099' }));
  });

  test('equipe não troca o doador da doação', async () => {
    await assertFails(updateDoc(doc(db('admin'), 'donations', 'd-pendente'), { donorId: 'outra' }));
  });

  test('voluntário não opera doações', async () => {
    await assertFails(updateDoc(doc(db('voluntario'), 'donations', 'd-pendente'), { status: 'aprovada' }));
  });
});

describe('A03 — imagens de produtos no Storage', () => {
  const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const storage = (uid) => env.authenticatedContext(uid).storage();
  const path = 'products/p1/foto.png';

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), path), png, { contentType: 'image/png' });
    });
  });

  test('estoquista e admin ativos enviam e apagam fotos', async () => {
    await assertSucceeds(uploadBytes(ref(storage('estoquista'), 'products/p1/nova.png'), png,
      { contentType: 'image/png' }));
    await assertSucceeds(deleteObject(ref(storage('admin'), path)));
  });

  test('doador não envia nem apaga fotos do estoque', async () => {
    await assertFails(uploadBytes(ref(storage('doador'), 'products/p1/x.png'), png, { contentType: 'image/png' }));
    await assertFails(deleteObject(ref(storage('doador'), path)));
  });

  test('voluntário e admin desativado não alteram fotos', async () => {
    await assertFails(uploadBytes(ref(storage('voluntario'), 'products/p1/x.png'), png, { contentType: 'image/png' }));
    await assertFails(deleteObject(ref(storage('adminInativo'), path)));
  });

  test('arquivo que não é imagem é recusado', async () => {
    await assertFails(uploadBytes(ref(storage('estoquista'), 'products/p1/x.txt'),
      new TextEncoder().encode('oi'), { contentType: 'text/plain' }));
  });

  test('qualquer usuário logado vê as fotos; anônimo não', async () => {
    await assertSucceeds(getBytes(ref(storage('doador'), path)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), path)));
  });
});
