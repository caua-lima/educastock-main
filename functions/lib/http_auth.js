"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.STAFF_WRITE_ROLES = void 0;
exports.requireActiveStaff = requireActiveStaff;
exports.cleanText = cleanText;
exports.cleanInt = cleanInt;
/** Papéis da equipe que podem acionar as rotas HTTP que gravam dados. */
exports.STAFF_WRITE_ROLES = ['admin', 'estoquista'];
/**
 * Middleware: exige `Authorization: Bearer <ID token>` de um administrador ou estoquista
 * ATIVO (auditoria A14). As rotas usam o Admin SDK, que ignora as regras do Firestore —
 * por isso a autorização precisa acontecer aqui.
 */
function requireActiveStaff(deps) {
    return async (req, res, next) => {
        var _a, _b;
        const header = (_a = req.header('authorization')) !== null && _a !== void 0 ? _a : '';
        const match = /^Bearer (.+)$/i.exec(header);
        if (!match) {
            res.status(401).json({ error: 'Autenticação necessária.' });
            return;
        }
        let uid;
        try {
            uid = (await deps.verifyToken(match[1])).uid;
        }
        catch (_c) {
            res.status(401).json({ error: 'Sessão inválida ou expirada.' });
            return;
        }
        const profile = await deps.loadProfile(uid);
        if (!profile || profile.isActive !== true || !exports.STAFF_WRITE_ROLES.includes((_b = profile.role) !== null && _b !== void 0 ? _b : '')) {
            res.status(403).json({ error: 'Sem permissão para esta operação.' });
            return;
        }
        res.locals.uid = uid;
        next();
    };
}
/** Texto obrigatório, sem espaços nas pontas, com tamanho máximo. */
function cleanText(value, max = 200) {
    if (typeof value !== 'string')
        return null;
    const t = value.trim();
    return t.length === 0 || t.length > max ? null : t;
}
/** Inteiro não negativo dentro de um limite razoável. */
function cleanInt(value, max = 1000000) {
    return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= max
        ? value
        : null;
}
//# sourceMappingURL=http_auth.js.map