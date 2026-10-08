import express, { Request, Response } from 'express';
import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();

const app = express();
app.use(express.json());

// Health check
app.get('/', (_req: Request, res: Response) => {
  res.json({ status: 'OK', service: 'educastock-functions' });
});

// Alerta de estoque baixo
app.post('/alertLowStock', async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const productName: string = data?.name ?? 'Produto desconhecido';
    const quantity: number = data?.quantity ?? 0;

    await db.collection('alerts').add({
      type: 'low_stock',
      productName,
      quantity,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: `Alerta criado para ${productName}` });
  } catch (err) {
    console.error('alertLowStock error:', err);
    res.status(500).json({ error: String(err) });
  }
});

// Alerta de validade próxima
app.post('/alertExpiryWarning', async (req: Request, res: Response) => {
  try {
    const data = req.body;
    const productName: string = data?.productName ?? 'Produto desconhecido';
    const expiryDate: string = data?.expiryDate ?? '';
    const batchId: string = data?.batchId ?? '';

    await db.collection('alerts').add({
      type: 'expiry_warning',
      productName,
      expiryDate,
      batchId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: `Alerta de validade criado para ${productName}` });
  } catch (err) {
    console.error('alertExpiryWarning error:', err);
    res.status(500).json({ error: String(err) });
  }
});

// Notificação de movimentação de estoque
app.post('/notifyStockMovement', async (req: Request, res: Response) => {
  try {
    const data = req.body;

    await db.collection('notifications').add({
      type: 'stock_movement',
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true });
  } catch (err) {
    console.error('notifyStockMovement error:', err);
    res.status(500).json({ error: String(err) });
  }
});

// Geração de relatório
app.post('/generateReport', async (req: Request, res: Response) => {
  try {
    const data = req.body;

    const reportRef = await db.collection('reports').add({
      status: 'pending',
      requestedBy: data?.userId ?? 'unknown',
      type: data?.type ?? 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, reportId: reportRef.id });
  } catch (err) {
    console.error('generateReport error:', err);
    res.status(500).json({ error: String(err) });
  }
});

const PORT = process.env.PORT ?? 8080;
app.listen(PORT, () => {
  console.log(`educastock-functions listening on port ${PORT}`);
});

// Portal do Doador (Sprint 5): gatilhos Firestore das doações.
export { onDonationCreated, onDonationStatusChanged } from './donations';
