import express, { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { cleanInt, cleanText, requireActiveStaff } from './http_auth';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

const app = express();
// Corpo pequeno: as rotas só recebem alguns campos.
app.use(express.json({ limit: '16kb' }));

// Todas as rotas que gravam exigem administrador/estoquista ATIVO (auditoria A14).
const requireStaff = requireActiveStaff({
  verifyToken: (token) => admin.auth().verifyIdToken(token),
  loadProfile: async (uid) => (await db.doc(`users/${uid}`).get()).data(),
});

/** Erro interno: registra no log e responde sem expor detalhes. */
function fail(res: Response, where: string, err: unknown): void {
  console.error(`${where} error:`, err);
  res.status(500).json({ error: 'Erro interno. Tente novamente.' });
}

// Health check (público, não grava nada)
app.get('/', (_req: Request, res: Response) => {
  res.json({ status: 'OK', service: 'educastock-functions' });
});

// Alerta de estoque baixo
app.post('/alertLowStock', requireStaff, async (req: Request, res: Response) => {
  const productName = cleanText(req.body?.name);
  const quantity = cleanInt(req.body?.quantity);
  if (productName === null || quantity === null) {
    res.status(400).json({ error: 'Informe "name" (texto) e "quantity" (inteiro ≥ 0).' });
    return;
  }
  try {
    await db.collection('alerts').add({
      type: 'low_stock',
      productName,
      quantity,
      createdBy: res.locals.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true, message: `Alerta criado para ${productName}` });
  } catch (err) {
    fail(res, 'alertLowStock', err);
  }
});

// Alerta de validade próxima
app.post('/alertExpiryWarning', requireStaff, async (req: Request, res: Response) => {
  const productName = cleanText(req.body?.productName);
  const expiryDate = cleanText(req.body?.expiryDate, 40);
  const batchId = cleanText(req.body?.batchId, 128);
  if (productName === null || expiryDate === null || batchId === null || isNaN(Date.parse(expiryDate))) {
    res.status(400).json({ error: 'Informe "productName", "expiryDate" (data) e "batchId".' });
    return;
  }
  try {
    await db.collection('alerts').add({
      type: 'expiry_warning',
      productName,
      expiryDate,
      batchId,
      createdBy: res.locals.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true, message: `Alerta de validade criado para ${productName}` });
  } catch (err) {
    fail(res, 'alertExpiryWarning', err);
  }
});

// Notificação de movimentação de estoque (só campos conhecidos — antes gravava o corpo inteiro)
app.post('/notifyStockMovement', requireStaff, async (req: Request, res: Response) => {
  const productName = cleanText(req.body?.productName);
  const movementType = cleanText(req.body?.type, 40);
  const quantity = cleanInt(req.body?.quantity);
  if (productName === null || movementType === null || quantity === null) {
    res.status(400).json({ error: 'Informe "productName", "type" e "quantity".' });
    return;
  }
  try {
    await db.collection('notifications').add({
      type: 'stock_movement',
      productName,
      movementType,
      quantity,
      createdBy: res.locals.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true });
  } catch (err) {
    fail(res, 'notifyStockMovement', err);
  }
});

// Geração de relatório (quem pede é quem está autenticado, não um campo do corpo)
app.post('/generateReport', requireStaff, async (req: Request, res: Response) => {
  const type = cleanText(req.body?.type ?? 'general', 40);
  if (type === null) {
    res.status(400).json({ error: 'Tipo de relatório inválido.' });
    return;
  }
  try {
    const reportRef = await db.collection('reports').add({
      status: 'pending',
      requestedBy: res.locals.uid,
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    res.json({ success: true, reportId: reportRef.id });
  } catch (err) {
    fail(res, 'generateReport', err);
  }
});

// O servidor Express só sobe quando o arquivo é executado direto (`npm start`, Cloud Run).
// Ao ser carregado pelo Firebase Functions (deploy), só as funções exportadas abaixo valem;
// subir a porta ali travava a descoberta das funções.
if (require.main === module) {
  const PORT = process.env.PORT ?? 8080;
  app.listen(PORT, () => {
    console.log(`educastock-functions listening on port ${PORT}`);
  });
}

// Portal do Doador (Sprint 5): gatilhos Firestore das doações.
export { onDonationCreated, onDonationStatusChanged } from './donations';

// Alertas de validade: push ao criar alerta e verificação diária.
export { onAlertCreated, dailyExpiryCheck } from './alerts';
