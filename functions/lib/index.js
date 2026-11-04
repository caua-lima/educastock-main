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
exports.dailyExpiryCheck = exports.onAlertCreated = exports.onDonationStatusChanged = exports.onDonationCreated = void 0;
const express_1 = __importDefault(require("express"));
const admin = __importStar(require("firebase-admin"));
const http_auth_1 = require("./http_auth");
if (admin.apps.length === 0) {
    admin.initializeApp();
}
const db = admin.firestore();
const app = (0, express_1.default)();
// Corpo pequeno: as rotas só recebem alguns campos.
app.use(express_1.default.json({ limit: '16kb' }));
// Todas as rotas que gravam exigem administrador/estoquista ATIVO (auditoria A14).
const requireStaff = (0, http_auth_1.requireActiveStaff)({
    verifyToken: (token) => admin.auth().verifyIdToken(token),
    loadProfile: async (uid) => (await db.doc(`users/${uid}`).get()).data(),
});
/** Erro interno: registra no log e responde sem expor detalhes. */
function fail(res, where, err) {
    console.error(`${where} error:`, err);
    res.status(500).json({ error: 'Erro interno. Tente novamente.' });
}
// Health check (público, não grava nada)
app.get('/', (_req, res) => {
    res.json({ status: 'OK', service: 'educastock-functions' });
});
// Alerta de estoque baixo
app.post('/alertLowStock', requireStaff, async (req, res) => {
    var _a, _b;
    const productName = (0, http_auth_1.cleanText)((_a = req.body) === null || _a === void 0 ? void 0 : _a.name);
    const quantity = (0, http_auth_1.cleanInt)((_b = req.body) === null || _b === void 0 ? void 0 : _b.quantity);
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
    }
    catch (err) {
        fail(res, 'alertLowStock', err);
    }
});
// Alerta de validade próxima
app.post('/alertExpiryWarning', requireStaff, async (req, res) => {
    var _a, _b, _c;
    const productName = (0, http_auth_1.cleanText)((_a = req.body) === null || _a === void 0 ? void 0 : _a.productName);
    const expiryDate = (0, http_auth_1.cleanText)((_b = req.body) === null || _b === void 0 ? void 0 : _b.expiryDate, 40);
    const batchId = (0, http_auth_1.cleanText)((_c = req.body) === null || _c === void 0 ? void 0 : _c.batchId, 128);
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
    }
    catch (err) {
        fail(res, 'alertExpiryWarning', err);
    }
});
// Notificação de movimentação de estoque (só campos conhecidos — antes gravava o corpo inteiro)
app.post('/notifyStockMovement', requireStaff, async (req, res) => {
    var _a, _b, _c;
    const productName = (0, http_auth_1.cleanText)((_a = req.body) === null || _a === void 0 ? void 0 : _a.productName);
    const movementType = (0, http_auth_1.cleanText)((_b = req.body) === null || _b === void 0 ? void 0 : _b.type, 40);
    const quantity = (0, http_auth_1.cleanInt)((_c = req.body) === null || _c === void 0 ? void 0 : _c.quantity);
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
    }
    catch (err) {
        fail(res, 'notifyStockMovement', err);
    }
});
// Geração de relatório (quem pede é quem está autenticado, não um campo do corpo)
app.post('/generateReport', requireStaff, async (req, res) => {
    var _a, _b;
    const type = (0, http_auth_1.cleanText)((_b = (_a = req.body) === null || _a === void 0 ? void 0 : _a.type) !== null && _b !== void 0 ? _b : 'general', 40);
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
    }
    catch (err) {
        fail(res, 'generateReport', err);
    }
});
// O servidor Express só sobe quando o arquivo é executado direto (`npm start`, Cloud Run).
// Ao ser carregado pelo Firebase Functions (deploy), só as funções exportadas abaixo valem;
// subir a porta ali travava a descoberta das funções.
if (require.main === module) {
    const PORT = (_a = process.env.PORT) !== null && _a !== void 0 ? _a : 8080;
    app.listen(PORT, () => {
        console.log(`educastock-functions listening on port ${PORT}`);
    });
}
// Portal do Doador (Sprint 5): gatilhos Firestore das doações.
var donations_1 = require("./donations");
Object.defineProperty(exports, "onDonationCreated", { enumerable: true, get: function () { return donations_1.onDonationCreated; } });
Object.defineProperty(exports, "onDonationStatusChanged", { enumerable: true, get: function () { return donations_1.onDonationStatusChanged; } });
// Alertas de validade: push ao criar alerta e verificação diária.
var alerts_1 = require("./alerts");
Object.defineProperty(exports, "onAlertCreated", { enumerable: true, get: function () { return alerts_1.onAlertCreated; } });
Object.defineProperty(exports, "dailyExpiryCheck", { enumerable: true, get: function () { return alerts_1.dailyExpiryCheck; } });
//# sourceMappingURL=index.js.map