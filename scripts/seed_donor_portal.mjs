/**
 * Seed SOMENTE do Portal do Doador (necessidades, ponto de recebimento e regras).
 * Não toca em users, products, batches etc. — seguro para rodar em produção.
 *
 * Pré-requisito: rodar de dentro de functions/ (onde firebase-admin está instalado)
 * com credenciais: `gcloud auth application-default login` ou
 * GOOGLE_APPLICATION_CREDENTIALS apontando para a service account.
 *
 * Execução (a partir da raiz do projeto):
 *   cd functions && node ../scripts/seed_donor_portal.mjs
 *
 * Ajuste endereço, contato e horários do ponto ANTES de rodar.
 */
import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

if (!getApps().length) initializeApp({ credential: applicationDefault(), projectId: 'educastock-69936' });
const db = getFirestore();

// Date vira Timestamp no Firestore, igual ao que as Cloud Functions gravam.
const dateAgo = (n) => new Date(Date.now() - n * 86_400_000);

const NEEDS = [
  { id: 'need-leite',      source: 'manual', categoryId: 'alimento',       title: 'Leite integral 1 L',  unit: 'un', priority: 'critica', priorityRank: 1, suggestedQty: 150, pledgedQty: 0, remainingQty: 150, minShelfLifeDays: 60, isActive: true, updatedAt: dateAgo(0) },
  { id: 'need-arroz',      source: 'manual', categoryId: 'alimento',       title: 'Arroz tipo 1 · 5 kg', unit: 'un', priority: 'alta',    priorityRank: 2, suggestedQty: 60,  pledgedQty: 0, remainingQty: 60,  minShelfLifeDays: 90, isActive: true, updatedAt: dateAgo(1) },
  { id: 'need-detergente', source: 'manual', categoryId: 'limpeza',        title: 'Detergente 500 mL',   unit: 'un', priority: 'alta',    priorityRank: 2, suggestedQty: 60,  pledgedQty: 0, remainingQty: 60,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(2) },
  { id: 'need-sabonete',   source: 'manual', categoryId: 'higienePessoal', title: 'Sabonete em barra',   unit: 'un', priority: 'normal',  priorityRank: 3, suggestedQty: 80,  pledgedQty: 0, remainingQty: 80,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(3) },
  { id: 'need-caderno',    source: 'manual', categoryId: 'escolar',        title: 'Caderno 96 folhas',   unit: 'un', priority: 'normal',  priorityRank: 3, suggestedQty: 50,  pledgedQty: 0, remainingQty: 50,  minShelfLifeDays: 0,  isActive: true, updatedAt: dateAgo(4) },
];

// weekday segue DateTime.weekday do Dart: 1 = segunda … 7 = domingo.
const POINTS = [
  {
    id: 'ponto-sede',
    name: 'Sede da Casa da Criança',
    address: 'AJUSTAR: endereço da sede',
    hours: [1, 2, 3, 4, 5].map((weekday) => ({ weekday, from: '09:00', to: '17:00' })).concat([{ weekday: 6, from: '09:00', to: '12:00' }]),
    contact: 'AJUSTAR: telefone/WhatsApp da coordenação',
    instructions: 'Procure a recepção e informe o protocolo da doação.',
    isActive: true,
  },
];

const RULES = { minShelfLifeDays: 30, maxOpenPledges: 3, maxItems: 20, blockedCategories: [] };

const batch = db.batch();
for (const { id, ...d } of NEEDS) batch.set(db.collection('donation_needs').doc(id), d);
for (const { id, ...d } of POINTS) batch.set(db.collection('donation_points').doc(id), d);
batch.set(db.collection('settings').doc('donation_rules'), RULES);
await batch.commit();
console.log(`OK: ${NEEDS.length} necessidades, ${POINTS.length} ponto(s) e settings/donation_rules gravados.`);
