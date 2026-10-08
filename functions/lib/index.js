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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.onDonationStatusChanged = exports.onDonationCreated = void 0;
const express_1 = __importDefault(require("express"));
const admin = __importStar(require("firebase-admin"));
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const app = (0, express_1.default)();
app.use(express_1.default.json());
// Health check
app.get('/', (_req, res) => {
    res.json({ status: 'OK', service: 'educastock-functions' });
});
// Alerta de estoque baixo
app.post('/alertLowStock', async (req, res) => {
    var _a, _b;
    try {
        const data = req.body;
        const productName = (_a = data === null || data === void 0 ? void 0 : data.name) !== null && _a !== void 0 ? _a : 'Produto desconhecido';
        const quantity = (_b = data === null || data === void 0 ? void 0 : data.quantity) !== null && _b !== void 0 ? _b : 0;
        await db.collection('alerts').add({
            type: 'low_stock',
            productName,
            quantity,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ success: true, message: `Alerta criado para ${productName}` });
    }
    catch (err) {
        console.error('alertLowStock error:', err);
        res.status(500).json({ error: String(err) });
    }
});
// Alerta de validade próxima
app.post('/alertExpiryWarning', async (req, res) => {
    var _a, _b, _c;
    try {
        const data = req.body;
        const productName = (_a = data === null || data === void 0 ? void 0 : data.productName) !== null && _a !== void 0 ? _a : 'Produto desconhecido';
        const expiryDate = (_b = data === null || data === void 0 ? void 0 : data.expiryDate) !== null && _b !== void 0 ? _b : '';
        const batchId = (_c = data === null || data === void 0 ? void 0 : data.batchId) !== null && _c !== void 0 ? _c : '';
        await db.collection('alerts').add({
            type: 'expiry_warning',
            productName,
            expiryDate,
            batchId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ success: true, message: `Alerta de validade criado para ${productName}` });
    }
    catch (err) {
        console.error('alertExpiryWarning error:', err);
        res.status(500).json({ error: String(err) });
    }
});
// Notificação de movimentação de estoque
app.post('/notifyStockMovement', async (req, res) => {
    try {
        const data = req.body;
        await db.collection('notifications').add(Object.assign(Object.assign({ type: 'stock_movement' }, data), { createdAt: admin.firestore.FieldValue.serverTimestamp() }));
        res.json({ success: true });
    }
    catch (err) {
        console.error('notifyStockMovement error:', err);
        res.status(500).json({ error: String(err) });
    }
});
// Geração de relatório
app.post('/generateReport', async (req, res) => {
    var _a, _b;
    try {
        const data = req.body;
        const reportRef = await db.collection('reports').add({
            status: 'pending',
            requestedBy: (_a = data === null || data === void 0 ? void 0 : data.userId) !== null && _a !== void 0 ? _a : 'unknown',
            type: (_b = data === null || data === void 0 ? void 0 : data.type) !== null && _b !== void 0 ? _b : 'general',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ success: true, reportId: reportRef.id });
    }
    catch (err) {
        console.error('generateReport error:', err);
        res.status(500).json({ error: String(err) });
    }
});
const PORT = (_a = process.env.PORT) !== null && _a !== void 0 ? _a : 8080;
app.listen(PORT, () => {
    console.log(`educastock-functions listening on port ${PORT}`);
});
// Portal do Doador (Sprint 5): gatilhos Firestore das doações.
var donations_1 = require("./donations");
Object.defineProperty(exports, "onDonationCreated", { enumerable: true, get: function () { return donations_1.onDonationCreated; } });
Object.defineProperty(exports, "onDonationStatusChanged", { enumerable: true, get: function () { return donations_1.onDonationStatusChanged; } });
//# sourceMappingURL=index.js.map