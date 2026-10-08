import * as admin from 'firebase-admin';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

// ─── Constantes de domínio (Sprint 2: RN-D05, RN-D06, seção 4.4) ───────────

type DonationStatus =
  | 'pendente'
  | 'aprovada'
  | 'recebida'
  | 'recebida_parcial'
  | 'recusada'
  | 'cancelada'
  | 'expirada';

const OPEN_STATUSES: DonationStatus[] = ['pendente', 'aprovada'];
const TERMINAL_STATUSES: DonationStatus[] = [
  'recebida',
  'recebida_parcial',
  'recusada',
  'cancelada',
  'expirada',
];

/** Transições permitidas (tabela 13 do relatório da Sprint 2). */
const ALLOWED_TRANSITIONS: Record<string, DonationStatus[]> = {
  pendente: ['aprovada', 'recusada', 'cancelada', 'expirada'],
  aprovada: ['recebida', 'recebida_parcial', 'cancelada', 'expirada'],
};

const DEFAULT_MAX_OPEN_PLEDGES = 3;
const DEFAULT_MAX_ITEMS = 20;

const STATUS_NOTIFICATION: Record<string, { title: string; body: string }> = {
  aprovada: {
    title: 'Doação aprovada',
    body: 'A equipe aprovou sua doação. Veja onde e quando entregar.',
  },
  recusada: {
    title: 'Doação recusada',
    body: 'A equipe não pôde aceitar esta doação. Veja o motivo no aplicativo.',
  },
  recebida: {
    title: 'Doação recebida',
    body: 'Recebemos sua doação. Obrigado por ajudar a Casa da Criança!',
  },
  recebida_parcial: {
    title: 'Doação recebida parcialmente',
    body: 'Recebemos parte da sua doação. Veja os detalhes no aplicativo.',
  },
  cancelada: {
    title: 'Doação cancelada',
    body: 'Sua doação foi cancelada.',
  },
  expirada: {
    title: 'Doação expirada',
    body: 'O prazo desta doação terminou sem entrega.',
  },
};

interface DonationItemDoc {
  needId?: string | null;
  quantity?: number;
  [key: string]: unknown;
}

// ─── Helpers puros (exportados para teste) ─────────────────────────────────

/** `DOA-AAAA-NNNNNN` a partir do ano e do contador sequencial. */
export function buildProtocol(year: number, sequence: number): string {
  return `DOA-${year}-${String(sequence).padStart(6, '0')}`;
}

export function isTransitionAllowed(from: string, to: string): boolean {
  return (ALLOWED_TRANSITIONS[from] ?? []).includes(to as DonationStatus);
}

/** Soma a quantidade prometida por necessidade (ignora itens sem `needId`). */
export function sumPledgesByNeed(items: DonationItemDoc[]): Map<string, number> {
  const pledges = new Map<string, number>();
  for (const item of items) {
    const needId = item.needId;
    const qty = Number(item.quantity ?? 0);
    if (!needId || !Number.isFinite(qty) || qty <= 0) continue;
    pledges.set(needId, (pledges.get(needId) ?? 0) + Math.floor(qty));
  }
  return pledges;
}

// ─── Reserva de quantidade prometida (RN-D05) ──────────────────────────────

/**
 * Aplica `delta` (+ reserva, − liberação) em `pledgedQty` das necessidades
 * citadas e recalcula `remainingQty = max(0, suggestedQty − pledgedQty)`.
 * Deve ser chamada DENTRO de uma transação (leituras antes das escritas).
 */
async function applyPledges(
  tx: FirebaseFirestore.Transaction,
  pledges: Map<string, number>,
  direction: 1 | -1,
): Promise<void> {
  const refs = [...pledges.keys()].map((id) => db.collection('donation_needs').doc(id));
  const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));

  snaps.forEach((snap, index) => {
    if (!snap.exists) return;
    const needId = refs[index].id;
    const qty = pledges.get(needId) ?? 0;
    const data = snap.data() ?? {};
    const suggested = Number(data.suggestedQty ?? 0);
    const pledged = Math.max(0, Number(data.pledgedQty ?? 0) + direction * qty);
    tx.update(snap.ref, {
      pledgedQty: pledged,
      remainingQty: Math.max(0, suggested - pledged),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

// ─── onDonationCreated ─────────────────────────────────────────────────────

/**
 * RF20: ao registrar a intenção, valida limites (RN-D06), gera o protocolo
 * `DOA-AAAA-NNNNNN`, reserva `pledgedQty` (RN-D05), cria o evento inicial e o
 * alerta da equipe. Idempotente: se já tem protocolo, não faz nada.
 */
export const onDonationCreated = onDocumentCreated('donations/{donationId}', async (event) => {
  const snap = event.data;
  if (!snap) return;

  const donation = snap.data();
  const ref = snap.ref;
  const donationId = event.params.donationId;

  if (donation.protocol) return; // já processada

  const items: DonationItemDoc[] = Array.isArray(donation.items) ? donation.items : [];
  const donorId: string = donation.donorId;

  // Regras configuráveis (settings/donation_rules) com padrões seguros.
  const rulesSnap = await db.doc('settings/donation_rules').get();
  const rules = rulesSnap.data() ?? {};
  const maxOpenPledges = Number(rules.maxOpenPledges ?? DEFAULT_MAX_OPEN_PLEDGES);
  const maxItems = Number(rules.maxItems ?? DEFAULT_MAX_ITEMS);

  // RN-D06: limite de itens e de intenções abertas por doador.
  const openSnap = await db
    .collection('donations')
    .where('donorId', '==', donorId)
    .where('status', 'in', OPEN_STATUSES)
    .get();
  const otherOpen = openSnap.docs.filter((d) => d.id !== donationId).length;

  const violation =
    items.length === 0 || items.length > maxItems
      ? 'limite_de_itens'
      : otherOpen >= maxOpenPledges
        ? 'limite_de_intencoes'
        : null;

  if (violation) {
    await ref.update({
      status: 'cancelada',
      cancelReason: violation,
      reservationReleased: true, // nada foi reservado
      updatedAt: FieldValue.serverTimestamp(),
    });
    await ref.collection('events').add({
      type: 'rejected',
      fromStatus: null,
      toStatus: 'cancelada',
      by: 'system',
      byRole: 'system',
      note: violation,
      at: FieldValue.serverTimestamp(),
    });
    logger.warn(`Doação ${donationId} rejeitada: ${violation}`);
    return;
  }

  const year = new Date().getFullYear();
  const counterRef = db.doc('settings/counters');
  const pledges = sumPledgesByNeed(items);

  const protocol = await db.runTransaction(async (tx) => {
    // Leituras primeiro (regra das transações do Firestore).
    const counterSnap = await tx.get(counterRef);
    const current = Number(counterSnap.data()?.[`donations_${year}`] ?? 0);
    const next = current + 1;

    // Reserva de quantidade prometida (lê as necessidades e escreve).
    await applyPledges(tx, pledges, 1);

    tx.set(counterRef, { [`donations_${year}`]: next }, { merge: true });
    const generated = buildProtocol(year, next);
    tx.update(ref, {
      protocol: generated,
      reservationApplied: true,
      reservationReleased: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return generated;
  });

  await ref.collection('events').add({
    type: 'created',
    fromStatus: null,
    toStatus: 'pendente',
    by: donorId,
    byRole: 'doador',
    note: protocol,
    at: FieldValue.serverTimestamp(),
  });

  // Alerta para a equipe (formato lido por StockAlert.fromMap).
  const donorName: string = donation.donorSnapshot?.displayName ?? 'Doador';
  await db.collection('alerts').add({
    productId: 'donation',
    productName: protocol,
    batchId: null,
    donationId,
    level: 'info',
    message: `Nova intenção de doação ${protocol} de ${donorName} (${items.length} item(ns)).`,
    createdAt: Timestamp.now(),
    resolved: false,
  });

  logger.info(`Doação ${donationId} registrada com protocolo ${protocol}`);
});

// ─── onDonationStatusChanged ───────────────────────────────────────────────

/**
 * Valida cada transição de status (seção 4.4), grava o evento na linha do
 * tempo e em `audit_logs`, libera a reserva ao fechar a doação e notifica o
 * doador (caixa de entrada + push best-effort). Transição inválida é revertida.
 */
export const onDonationStatusChanged = onDocumentUpdated('donations/{donationId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const ref = event.data?.after.ref;
  if (!before || !after || !ref) return;

  // Marcador deixado pela própria função ao reverter: só limpa e sai.
  if (after.transitionRejected === true) {
    await ref.update({ transitionRejected: FieldValue.delete() });
    return;
  }

  const fromStatus: string = before.status;
  const toStatus: string = after.status;
  if (fromStatus === toStatus) return;

  const donationId = event.params.donationId;

  if (!isTransitionAllowed(fromStatus, toStatus)) {
    await ref.update({
      status: fromStatus,
      transitionRejected: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    await ref.collection('events').add({
      type: 'invalid_transition',
      fromStatus,
      toStatus,
      by: 'system',
      byRole: 'system',
      note: 'Transição não permitida; status revertido.',
      at: FieldValue.serverTimestamp(),
    });
    logger.warn(`Doação ${donationId}: transição inválida ${fromStatus} -> ${toStatus}`);
    return;
  }

  // O doador só pode cancelar e não grava `updatedBy` (regras): atribui a ele.
  const actor: string =
    after.updatedBy ?? (toStatus === 'cancelada' ? after.donorId : 'unknown');

  // Linha do tempo + auditoria (RNF15).
  await ref.collection('events').add({
    type: 'status_changed',
    fromStatus,
    toStatus,
    by: actor,
    byRole: after.updatedByRole ?? (actor === after.donorId ? 'doador' : 'unknown'),
    note: after.refusalReason ?? after.cancelReason ?? null,
    at: FieldValue.serverTimestamp(),
  });
  await db.collection('audit_logs').add({
    collection: 'donations',
    documentId: donationId,
    action: `donation_${toStatus}`,
    before: { status: fromStatus },
    after: { status: toStatus },
    performedBy: actor,
    performedByName: after.updatedByName ?? (actor === after.donorId ? 'Doador' : 'Sistema'),
    performedAt: new Date().toISOString(),
  });

  // Libera a reserva ao entrar em estado terminal (RN-D05, RN-D09).
  if (
    TERMINAL_STATUSES.includes(toStatus as DonationStatus) &&
    after.reservationApplied === true &&
    after.reservationReleased !== true
  ) {
    const items: DonationItemDoc[] = Array.isArray(after.items) ? after.items : [];
    const pledges = sumPledgesByNeed(items);
    await db.runTransaction(async (tx) => {
      await applyPledges(tx, pledges, -1);
      tx.update(ref, { reservationReleased: true });
    });
  }

  await notifyDonor(after.donorId, donationId, after.protocol, toStatus);
});

// ─── Notificações ──────────────────────────────────────────────────────────

async function notifyDonor(
  donorId: string,
  donationId: string,
  protocol: string | undefined,
  status: string,
): Promise<void> {
  const template = STATUS_NOTIFICATION[status];
  if (!template || !donorId) return;

  const title = template.title;
  const body = protocol ? `${template.body} (${protocol})` : template.body;

  await db.collection('user_notifications').doc(donorId).collection('items').add({
    title,
    body,
    donationId,
    status,
    readAt: null,
    createdAt: FieldValue.serverTimestamp(),
  });

  // Push best-effort: o status no app é a fonte da verdade (RF24).
  try {
    const donorSnap = await db.doc(`donors/${donorId}`).get();
    if (donorSnap.data()?.prefs?.notificacoes === false) return;

    const tokensSnap = await db.collection('device_tokens').where('userId', '==', donorId).get();
    const tokens = tokensSnap.docs.map((d) => d.data().token as string).filter(Boolean);
    if (tokens.length === 0) return;

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { donationId, status },
    });
  } catch (err) {
    logger.warn('Falha ao enviar push ao doador (ignorada)', err);
  }
}
