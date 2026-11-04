// Testes das regras do Firestore por REQUISITO do Plano de Teste (Fatec, IQS004).
// Emulador, projeto "demo-educastock" (não existe na nuvem: nenhum dado real é tocado).
//
//   firebase emulators:exec --only firestore,storage --project demo-educastock "npm --prefix tests/rules test"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from 'firebase/firestore';

const root = new URL('../../', import.meta.url);
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-educastock',
    firestore: { rules: readFileSync(new URL('firestore.rules', root), 'utf8') },
  });
});
after(async () => env?.cleanup());

const USERS = {
  admin: { role: 'admin', isActive: true },
  estoquista: { role: 'estoquista', isActive: true },
  voluntario: { role: 'voluntario', isActive: true },
  consulta: { role: 'consulta', isActive: true },
  doador: { role: 'doador', isActive: true },
  outroDoador: { role: 'doador', isActive: true },
};

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, data] of Object.entries(USERS)) {
      await setDoc(doc(db, 'users', uid), { name: uid, email: `${uid}@teste.test`, ...data });
    }
    await setDoc(doc(db, 'audit_logs', 'a1'), { action: 'saida', performedBy: 'estoquista' });
    await setDoc(doc(db, 'stock_movements', 'm1'), { type: 'saida', quantity: 2 });
    await setDoc(doc(db, 'donors', 'doador'), {
      displayName: 'Doadora Teste', donorType: 'pf', consentAt: new Date(), termsVersion: '1.0',
    });
    await setDoc(doc(db, 'donors', 'doador', 'private', 'profile'), { cpf: '000.000.000-00' });
    await setDoc(doc(db, 'donation_needs', 'ativa'), { title: 'Leite', isActive: true });
    await setDoc(doc(db, 'donation_needs', 'inativa'), { title: 'Arroz', isActive: false });
    await setDoc(doc(db, 'donations', 'minha'), { donorId: 'doador', status: 'pendente', items: [{ q: 1 }] });
    await setDoc(doc(db, 'donations', 'alheia'), { donorId: 'outroDoador', status: 'pendente', items: [{ q: 1 }] });
    await setDoc(doc(db, 'user_notifications', 'doador', 'items', 'n1'), { title: 'Aprovada', readAt: null });
  });
});

const db = (uid, token = {}) => env.authenticatedContext(uid, token).firestore();

describe('RF01 / RNF04 — perfis e isolamento por papel', () => {
  test('equipe lê movimentações; doador e visitante não', async () => {
    for (const r of ['admin', 'estoquista', 'voluntario', 'consulta']) {
      await assertSucceeds(getDocs(collection(db(r), 'stock_movements')));
    }
    await assertFails(getDocs(collection(db('doador'), 'stock_movements')));
    await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'stock_movements')));
  });

  test('voluntário e consulta não gravam movimentações; estoquista grava', async () => {
    await assertFails(addDoc(collection(db('voluntario'), 'stock_movements'), { type: 'saida', quantity: 1 }));
    await assertFails(addDoc(collection(db('consulta'), 'stock_movements'), { type: 'saida', quantity: 1 }));
    await assertSucceeds(addDoc(collection(db('estoquista'), 'stock_movements'), { type: 'saida', quantity: 1 }));
  });

  test('cada pessoa lê o próprio perfil; só o admin lê o perfil dos outros', async () => {
    await assertSucceeds(getDoc(doc(db('voluntario'), 'users', 'voluntario')));
    await assertFails(getDoc(doc(db('voluntario'), 'users', 'admin')));
    await assertSucceeds(getDoc(doc(db('admin'), 'users', 'voluntario')));
  });
});

describe('RF06 — trilha de auditoria imutável', () => {
  test('ninguém altera nem apaga um registro de auditoria (nem o admin)', async () => {
    await assertFails(updateDoc(doc(db('admin'), 'audit_logs', 'a1'), { action: 'outra' }));
    await assertFails(deleteDoc(doc(db('admin'), 'audit_logs', 'a1')));
  });

  test('movimentação de estoque também é imutável depois de criada', async () => {
    await assertFails(updateDoc(doc(db('admin'), 'stock_movements', 'm1'), { quantity: 99 }));
    await assertFails(deleteDoc(doc(db('admin'), 'stock_movements', 'm1')));
  });

  test('auditoria só é lida por admin e estoquista', async () => {
    await assertSucceeds(getDoc(doc(db('estoquista'), 'audit_logs', 'a1')));
    await assertFails(getDoc(doc(db('voluntario'), 'audit_logs', 'a1')));
    await assertFails(getDoc(doc(db('doador'), 'audit_logs', 'a1')));
  });
});

describe('RF16 — autocadastro público só como doador', () => {
  test('nova conta cria o próprio perfil como doador ativo', async () => {
    await assertSucceeds(setDoc(doc(db('novo'), 'users', 'novo'),
      { name: 'Novo', email: 'novo@teste.test', role: 'doador', isActive: true }));
  });

  test('nova conta não se cadastra como admin nem estoquista', async () => {
    await assertFails(setDoc(doc(db('novo'), 'users', 'novo'),
      { name: 'Novo', email: 'n@t.test', role: 'admin', isActive: true }));
    await assertFails(setDoc(doc(db('novo'), 'users', 'novo'),
      { name: 'Novo', email: 'n@t.test', role: 'estoquista', isActive: true }));
  });

  test('ninguém cria o perfil de outra pessoa', async () => {
    await assertFails(setDoc(doc(db('novo'), 'users', 'outra'),
      { name: 'X', email: 'x@t.test', role: 'doador', isActive: true }));
  });

  test('perfil de doador exige aceite dos termos (consentAt) e versão', async () => {
    const base = { displayName: 'Doador Novo', donorType: 'pf', termsVersion: '1.0' };
    await assertFails(setDoc(doc(db('novo'), 'donors', 'novo'), base));
    await assertSucceeds(setDoc(doc(db('novo'), 'donors', 'novo'), { ...base, consentAt: serverTimestamp() }));
  });

  test('doação exige e-mail verificado', async () => {
    const d = {
      donorId: 'doador', donorSnapshot: {}, status: 'pendente', items: [{ q: 1 }], pointId: 'sede',
      window: null, termsAcceptedAt: serverTimestamp(), createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertFails(setDoc(doc(db('doador', { email_verified: false }), 'donations', 'nova'), d));
    await assertSucceeds(setDoc(doc(db('doador', { email_verified: true }), 'donations', 'nova'), d));
  });
});

describe('RF17 / RNF05 — dados pessoais do doador (LGPD)', () => {
  test('CPF/CNPJ (subcoleção private): só o dono e o admin leem', async () => {
    await assertSucceeds(getDoc(doc(db('doador'), 'donors', 'doador', 'private', 'profile')));
    await assertSucceeds(getDoc(doc(db('admin'), 'donors', 'doador', 'private', 'profile')));
    await assertFails(getDoc(doc(db('estoquista'), 'donors', 'doador', 'private', 'profile')));
    await assertFails(getDoc(doc(db('outroDoador'), 'donors', 'doador', 'private', 'profile')));
  });

  test('o doador não apaga o próprio perfil (exclusão é por pedido/anonimização)', async () => {
    await assertFails(deleteDoc(doc(db('doador'), 'donors', 'doador')));
    await assertSucceeds(updateDoc(doc(db('doador'), 'donors', 'doador'),
      { donorType: 'pf', deletionRequestedAt: serverTimestamp() }));
  });
});

describe('RF19 / RF24 — necessidades, doações e notificações do doador', () => {
  test('doador vê necessidades ativas; inativas não', async () => {
    await assertSucceeds(getDoc(doc(db('doador'), 'donation_needs', 'ativa')));
    await assertFails(getDoc(doc(db('doador'), 'donation_needs', 'inativa')));
  });

  test('doador vê só as próprias doações', async () => {
    await assertSucceeds(getDoc(doc(db('doador'), 'donations', 'minha')));
    await assertFails(getDoc(doc(db('doador'), 'donations', 'alheia')));
    await assertSucceeds(getDocs(query(collection(db('doador'), 'donations'), where('donorId', '==', 'doador'))));
  });

  test('caixa de notificações: só o dono lê e só marca como lida', async () => {
    const mine = doc(db('doador'), 'user_notifications', 'doador', 'items', 'n1');
    await assertSucceeds(getDoc(mine));
    await assertSucceeds(updateDoc(mine, { readAt: serverTimestamp() }));
    await assertFails(updateDoc(mine, { title: 'Alterado' }));
    await assertFails(getDoc(doc(db('outroDoador'), 'user_notifications', 'doador', 'items', 'n1')));
  });
});
