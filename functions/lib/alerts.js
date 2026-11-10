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
exports.dailyExpiryCheck = exports.onAlertCreated = void 0;
exports.classifyExpiry = classifyExpiry;
exports.civilDate = civilDate;
exports.daysUntil = daysUntil;
exports.alertMessage = alertMessage;
exports.topicConditionFor = topicConditionFor;
const admin = __importStar(require("firebase-admin"));
// Import modular: em admin.firestore.* os tipos podem vir indefinidos.
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const logger = __importStar(require("firebase-functions/logger"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
/**
 * Nível do alerta de validade para um lote que vence em `days` dias.
 * Retorna null quando está fora da janela de aviso. Mesma regra do aplicativo
 * (`AlertCheckerService`): vencido ou até `criticalDays` é crítico; até `warningDays`, aviso.
 */
function classifyExpiry(days, criticalDays, warningDays) {
    if (days <= criticalDays)
        return 'critical';
    if (days <= warningDays)
        return 'warning';
    return null;
}
/** Data de calendário (AAAA-MM-DD) de um instante no fuso da ONG. */
function civilDate(d, timeZone = 'America/Sao_Paulo') {
    return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' })
        .format(d);
}
/**
 * Dias de CALENDÁRIO entre hoje (no fuso da ONG) e a validade: 0 = vence hoje,
 * negativo = vencido. Mesma regra do app (auditoria A19). A validade gravada pelo app é
 * texto local ("2026-11-10T00:00:00.000"): só a data conta, sem conversão de fuso.
 */
function daysUntil(expiry, now, timeZone = 'America/Sao_Paulo') {
    const expiryDay = typeof expiry === 'string' ? expiry.slice(0, 10) : civilDate(expiry, timeZone);
    const today = civilDate(now, timeZone);
    const toUtc = (ymd) => {
        const [y, m, d] = ymd.split('-').map(Number);
        return Date.UTC(y, m - 1, d);
    };
    return Math.round((toUtc(expiryDay) - toUtc(today)) / 86400000);
}
function alertMessage(productName, days, level) {
    if (days <= 0)
        return `Lote VENCIDO — descarte imediato: ${productName}`;
    const plural = days === 1 ? '' : 's';
    return level === 'critical'
        ? `Crítico: "${productName}" vence em ${days} dia${plural}`
        : `Atenção: "${productName}" vence em ${days} dia${plural}`;
}
/**
 * Condição de tópico FCM do aplicativo: administradores e estoquistas assinam
 * `vencimento_critico` e `vencimento_aviso`; voluntários, só `vencimento_aviso`.
 * Crítico chega a todos; aviso, a quem assina o tópico de aviso.
 */
function topicConditionFor(level) {
    return level === 'critical'
        ? "'vencimento_critico' in topics || 'vencimento_aviso' in topics"
        : "'vencimento_aviso' in topics";
}
// ─── Push ao criar um alerta ───────────────────────────────────────────────
/**
 * Envia a notificação push (FCM) a cada alerta de validade novo, não importa quem o
 * criou: o aplicativo (verificação automática) ou a verificação diária abaixo.
 */
exports.onAlertCreated = (0, firestore_2.onDocumentCreated)('alerts/{alertId}', async (event) => {
    var _a, _b;
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data || data.resolved === true)
        return;
    const level = data.level;
    if (level !== 'critical' && level !== 'warning')
        return; // info (ex.: doações) não gera push
    const title = level === 'critical' ? 'Validade crítica' : 'Validade próxima';
    try {
        await admin.messaging().send({
            condition: topicConditionFor(level),
            notification: { title, body: String((_b = data.message) !== null && _b !== void 0 ? _b : '') },
            data: { alertId: event.params.alertId, level },
            android: { priority: 'high' },
        });
    }
    catch (err) {
        // O alerta no aplicativo é a fonte da verdade: falha de push não deve repetir a função.
        logger.warn('Falha ao enviar push do alerta', err);
    }
});
// ─── Verificação diária ────────────────────────────────────────────────────
/**
 * Todo dia às 7h (Brasília) cria os alertas de validade, mesmo que ninguém abra o
 * aplicativo. Não duplica: só cria se ainda não houver alerta aberto do mesmo nível
 * para o lote, e encerra os que já não valem.
 */
exports.dailyExpiryCheck = (0, scheduler_1.onSchedule)({ schedule: 'every day 07:00', timeZone: 'America/Sao_Paulo' }, async () => {
    var _a, _b, _c, _d, _e;
    const config = (_a = (await db.doc('settings/alerts').get()).data()) !== null && _a !== void 0 ? _a : {};
    if (config.expiryEnabled === false)
        return;
    const criticalDays = Number((_b = config.criticalDays) !== null && _b !== void 0 ? _b : 7);
    const warningDays = Math.max(Number((_c = config.warningDays) !== null && _c !== void 0 ? _c : 30), criticalDays + 1);
    const now = new Date();
    const limit = new Date(now.getTime() + warningDays * 86400000);
    const [batchesSnap, openSnap] = await Promise.all([
        db
            .collection('batches')
            .where('status', '==', 'disponivel')
            .where('noExpiry', '==', false)
            .where('expiryDate', '<=', limit.toISOString())
            .get(),
        db.collection('alerts').where('resolved', '==', false).get(),
    ]);
    const openLevels = new Map();
    for (const doc of openSnap.docs) {
        const d = doc.data();
        if (!d.batchId || d.productId === 'manual')
            continue;
        const set = (_d = openLevels.get(d.batchId)) !== null && _d !== void 0 ? _d : new Set();
        set.add(d.level);
        openLevels.set(d.batchId, set);
    }
    const writer = db.bulkWriter();
    const currentLevel = new Map();
    let created = 0;
    for (const doc of batchesSnap.docs) {
        const b = doc.data();
        if (!b.expiryDate)
            continue;
        const days = daysUntil(String(b.expiryDate), now);
        const level = classifyExpiry(days, criticalDays, warningDays);
        if (!level)
            continue;
        currentLevel.set(doc.id, level);
        if ((_e = openLevels.get(doc.id)) === null || _e === void 0 ? void 0 : _e.has(level))
            continue;
        void writer.create(db.collection('alerts').doc(), {
            productId: b.productId,
            productName: b.productName,
            batchId: doc.id,
            level,
            message: alertMessage(String(b.productName), days, level),
            createdAt: firestore_1.Timestamp.now(),
            resolved: false,
        });
        created++;
    }
    for (const doc of openSnap.docs) {
        const d = doc.data();
        if (!d.batchId || d.productId === 'manual')
            continue;
        if (currentLevel.get(d.batchId) !== d.level) {
            void writer.update(doc.ref, { resolved: true });
        }
    }
    await writer.close();
    logger.info(`Verificação diária: ${created} alerta(s) criado(s).`);
});
//# sourceMappingURL=alerts.js.map