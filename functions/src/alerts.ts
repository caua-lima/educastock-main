import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── Regras puras (exportadas para teste) ──────────────────────────────────

export type AlertLevel = 'critical' | 'warning';

/**
 * Nível do alerta de validade para um lote que vence em `days` dias.
 * Retorna null quando está fora da janela de aviso. Mesma regra do aplicativo
 * (`AlertCheckerService`): vencido ou até `criticalDays` é crítico; até `warningDays`, aviso.
 */
export function classifyExpiry(
  days: number,
  criticalDays: number,
  warningDays: number,
): AlertLevel | null {
  if (days <= criticalDays) return 'critical';
  if (days <= warningDays) return 'warning';
  return null;
}

/** Data de calendário (AAAA-MM-DD) de um instante no fuso da ONG. */
export function civilDate(d: Date, timeZone = 'America/Sao_Paulo'): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(d);
}

/**
 * Dias de CALENDÁRIO entre hoje (no fuso da ONG) e a validade: 0 = vence hoje,
 * negativo = vencido. Mesma regra do app (auditoria A19). A validade gravada pelo app é
 * texto local ("2026-11-10T00:00:00.000"): só a data conta, sem conversão de fuso.
 */
export function daysUntil(expiry: string | Date, now: Date, timeZone = 'America/Sao_Paulo'): number {
  const expiryDay = typeof expiry === 'string' ? expiry.slice(0, 10) : civilDate(expiry, timeZone);
  const today = civilDate(now, timeZone);
  const toUtc = (ymd: string) => {
    const [y, m, d] = ymd.split('-').map(Number);
    return Date.UTC(y, m - 1, d);
  };
  return Math.round((toUtc(expiryDay) - toUtc(today)) / 86_400_000);
}

export function alertMessage(productName: string, days: number, level: AlertLevel): string {
  if (days <= 0) return `Lote VENCIDO — descarte imediato: ${productName}`;
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
export function topicConditionFor(level: AlertLevel): string {
  return level === 'critical'
    ? "'vencimento_critico' in topics || 'vencimento_aviso' in topics"
    : "'vencimento_aviso' in topics";
}

// ─── Push ao criar um alerta ───────────────────────────────────────────────

/**
 * Envia a notificação push (FCM) a cada alerta de validade novo, não importa quem o
 * criou: o aplicativo (verificação automática) ou a verificação diária abaixo.
 */
export const onAlertCreated = onDocumentCreated('alerts/{alertId}', async (event) => {
  const data = event.data?.data();
  if (!data || data.resolved === true) return;

  const level = data.level as string | undefined;
  if (level !== 'critical' && level !== 'warning') return; // info (ex.: doações) não gera push

  const title = level === 'critical' ? 'Validade crítica' : 'Validade próxima';
  try {
    await admin.messaging().send({
      condition: topicConditionFor(level),
      notification: { title, body: String(data.message ?? '') },
      data: { alertId: event.params.alertId, level },
      android: { priority: 'high' },
    });
  } catch (err) {
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
export const dailyExpiryCheck = onSchedule(
  { schedule: 'every day 07:00', timeZone: 'America/Sao_Paulo' },
  async () => {
    const config = (await db.doc('settings/alerts').get()).data() ?? {};
    if (config.expiryEnabled === false) return;
    const criticalDays = Number(config.criticalDays ?? 7);
    const warningDays = Math.max(Number(config.warningDays ?? 30), criticalDays + 1);

    const now = new Date();
    const limit = new Date(now.getTime() + warningDays * 86_400_000);

    const [batchesSnap, openSnap] = await Promise.all([
      db
        .collection('batches')
        .where('status', '==', 'disponivel')
        .where('noExpiry', '==', false)
        .where('expiryDate', '<=', limit.toISOString())
        .get(),
      db.collection('alerts').where('resolved', '==', false).get(),
    ]);

    const openLevels = new Map<string, Set<string>>();
    for (const doc of openSnap.docs) {
      const d = doc.data();
      if (!d.batchId || d.productId === 'manual') continue;
      const set = openLevels.get(d.batchId) ?? new Set<string>();
      set.add(d.level);
      openLevels.set(d.batchId, set);
    }

    const writer = db.bulkWriter();
    const currentLevel = new Map<string, AlertLevel>();
    let created = 0;

    for (const doc of batchesSnap.docs) {
      const b = doc.data();
      if (!b.expiryDate) continue;
      const days = daysUntil(String(b.expiryDate), now);
      const level = classifyExpiry(days, criticalDays, warningDays);
      if (!level) continue;
      currentLevel.set(doc.id, level);
      if (openLevels.get(doc.id)?.has(level)) continue;

      void writer.create(db.collection('alerts').doc(), {
        productId: b.productId,
        productName: b.productName,
        batchId: doc.id,
        level,
        message: alertMessage(String(b.productName), days, level),
        createdAt: admin.firestore.Timestamp.now(),
        resolved: false,
      });
      created++;
    }

    for (const doc of openSnap.docs) {
      const d = doc.data();
      if (!d.batchId || d.productId === 'manual') continue;
      if (currentLevel.get(d.batchId) !== d.level) {
        void writer.update(doc.ref, { resolved: true });
      }
    }

    await writer.close();
    logger.info(`Verificação diária: ${created} alerta(s) criado(s).`);
  },
);
