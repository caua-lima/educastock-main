"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onDonationStatusChanged = exports.onDonationCreated = void 0;
exports.buildProtocol = buildProtocol;
exports.isTransitionAllowed = isTransitionAllowed;
exports.sumPledgesByNeed = sumPledgesByNeed;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const logger = __importStar(require("firebase-functions/logger"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const OPEN_STATUSES = ['pendente', 'aprovada'];
const TERMINAL_STATUSES = [
    'recebida',
    'recebida_parcial',
    'recusada',
    'cancelada',
    'expirada',
];
/** Transições permitidas (tabela 13 do relatório da Sprint 2). */
const ALLOWED_TRANSITIONS = {
    pendente: ['aprovada', 'recusada', 'cancelada', 'expirada'],
    aprovada: ['recebida', 'recebida_parcial', 'cancelada', 'expirada'],
};
const DEFAULT_MAX_OPEN_PLEDGES = 3;
const DEFAULT_MAX_ITEMS = 20;
const STATUS_NOTIFICATION = {
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
// ─── Helpers puros (exportados para teste) ─────────────────────────────────
/** `DOA-AAAA-NNNNNN` a partir do ano e do contador sequencial. */
function buildProtocol(year, sequence) {
    return `DOA-${year}-${String(sequence).padStart(6, '0')}`;
}
function isTransitionAllowed(from, to) {
    var _a;
    return ((_a = ALLOWED_TRANSITIONS[from]) !== null && _a !== void 0 ? _a : []).includes(to);
}
/** Soma a quantidade prometida por necessidade (ignora itens sem `needId`). */
function sumPledgesByNeed(items) {
    var _a, _b;
    const pledges = new Map();
    for (const item of items) {
        const needId = item.needId;
        const qty = Number((_a = item.quantity) !== null && _a !== void 0 ? _a : 0);
        if (!needId || !Number.isFinite(qty) || qty <= 0)
            continue;
        pledges.set(needId, ((_b = pledges.get(needId)) !== null && _b !== void 0 ? _b : 0) + Math.floor(qty));
    }
    return pledges;
}
// ─── Reserva de quantidade prometida (RN-D05) ──────────────────────────────
/**
 * Aplica `delta` (+ reserva, − liberação) em `pledgedQty` das necessidades
 * citadas e recalcula `remainingQty = max(0, suggestedQty − pledgedQty)`.
 * Deve ser chamada DENTRO de uma transação (leituras antes das escritas).
 */
async function applyPledges(tx, pledges, direction) {
    const refs = [...pledges.keys()].map((id) => db.collection('donation_needs').doc(id));
    const snaps = await Promise.all(refs.map((ref) => tx.get(ref)));
    snaps.forEach((snap, index) => {
        var _a, _b, _c, _d;
        if (!snap.exists)
            return;
        const needId = refs[index].id;
        const qty = (_a = pledges.get(needId)) !== null && _a !== void 0 ? _a : 0;
        const data = (_b = snap.data()) !== null && _b !== void 0 ? _b : {};
        const suggested = Number((_c = data.suggestedQty) !== null && _c !== void 0 ? _c : 0);
        const pledged = Math.max(0, Number((_d = data.pledgedQty) !== null && _d !== void 0 ? _d : 0) + direction * qty);
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
exports.onDonationCreated = (0, firestore_1.onDocumentCreated)('donations/{donationId}', async (event) => {
    var _a, _b, _c, _d, _e;
    const snap = event.data;
    if (!snap)
        return;
    const donation = snap.data();
    const ref = snap.ref;
    const donationId = event.params.donationId;
    if (donation.protocol)
        return; // já processada
    const items = Array.isArray(donation.items) ? donation.items : [];
    const donorId = donation.donorId;
    // Regras configuráveis (settings/donation_rules) com padrões seguros.
    const rulesSnap = await db.doc('settings/donation_rules').get();
    const rules = (_a = rulesSnap.data()) !== null && _a !== void 0 ? _a : {};
    const maxOpenPledges = Number((_b = rules.maxOpenPledges) !== null && _b !== void 0 ? _b : DEFAULT_MAX_OPEN_PLEDGES);
    const maxItems = Number((_c = rules.maxItems) !== null && _c !== void 0 ? _c : DEFAULT_MAX_ITEMS);
    // RN-D06: limite de itens e de intenções abertas por doador.
    const openSnap = await db
        .collection('donations')
        .where('donorId', '==', donorId)
        .where('status', 'in', OPEN_STATUSES)
        .get();
    const otherOpen = openSnap.docs.filter((d) => d.id !== donationId).length;
    const violation = items.length === 0 || items.length > maxItems
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
        var _a, _b;
        // Leituras primeiro (regra das transações do Firestore).
        const counterSnap = await tx.get(counterRef);
        const current = Number((_b = (_a = counterSnap.data()) === null || _a === void 0 ? void 0 : _a[`donations_${year}`]) !== null && _b !== void 0 ? _b : 0);
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
    const donorName = (_e = (_d = donation.donorSnapshot) === null || _d === void 0 ? void 0 : _d.displayName) !== null && _e !== void 0 ? _e : 'Doador';
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
exports.onDonationStatusChanged = (0, firestore_1.onDocumentUpdated)('donations/{donationId}', async (event) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const before = (_a = event.data) === null || _a === void 0 ? void 0 : _a.before.data();
    const after = (_b = event.data) === null || _b === void 0 ? void 0 : _b.after.data();
    const ref = (_c = event.data) === null || _c === void 0 ? void 0 : _c.after.ref;
    if (!before || !after || !ref)
        return;
    // Marcador deixado pela própria função ao reverter: só limpa e sai.
    if (after.transitionRejected === true) {
        await ref.update({ transitionRejected: FieldValue.delete() });
        return;
    }
    const fromStatus = before.status;
    const toStatus = after.status;
    if (fromStatus === toStatus)
        return;
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
    const actor = (_d = after.updatedBy) !== null && _d !== void 0 ? _d : (toStatus === 'cancelada' ? after.donorId : 'unknown');
    // Linha do tempo + auditoria (RNF15).
    await ref.collection('events').add({
        type: 'status_changed',
        fromStatus,
        toStatus,
        by: actor,
        byRole: (_e = after.updatedByRole) !== null && _e !== void 0 ? _e : (actor === after.donorId ? 'doador' : 'unknown'),
        note: (_g = (_f = after.refusalReason) !== null && _f !== void 0 ? _f : after.cancelReason) !== null && _g !== void 0 ? _g : null,
        at: FieldValue.serverTimestamp(),
    });
    await db.collection('audit_logs').add({
        collection: 'donations',
        documentId: donationId,
        action: `donation_${toStatus}`,
        before: { status: fromStatus },
        after: { status: toStatus },
        performedBy: actor,
        performedByName: (_h = after.updatedByName) !== null && _h !== void 0 ? _h : (actor === after.donorId ? 'Doador' : 'Sistema'),
        performedAt: new Date().toISOString(),
    });
    // Libera a reserva ao entrar em estado terminal (RN-D05, RN-D09).
    if (TERMINAL_STATUSES.includes(toStatus) &&
        after.reservationApplied === true &&
        after.reservationReleased !== true) {
        const items = Array.isArray(after.items) ? after.items : [];
        const pledges = sumPledgesByNeed(items);
        await db.runTransaction(async (tx) => {
            await applyPledges(tx, pledges, -1);
            tx.update(ref, { reservationReleased: true });
        });
    }
    await notifyDonor(after.donorId, donationId, after.protocol, toStatus);
});
// ─── Notificações ──────────────────────────────────────────────────────────
async function notifyDonor(donorId, donationId, protocol, status) {
    var _a, _b;
    const template = STATUS_NOTIFICATION[status];
    if (!template || !donorId)
        return;
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
        if (((_b = (_a = donorSnap.data()) === null || _a === void 0 ? void 0 : _a.prefs) === null || _b === void 0 ? void 0 : _b.notificacoes) === false)
            return;
        const tokensSnap = await db.collection('device_tokens').where('userId', '==', donorId).get();
        const tokens = tokensSnap.docs.map((d) => d.data().token).filter(Boolean);
        if (tokens.length === 0)
            return;
        await admin.messaging().sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: { donationId, status },
        });
    }
    catch (err) {
        logger.warn('Falha ao enviar push ao doador (ignorada)', err);
    }
}
//# sourceMappingURL=donations.js.map