import type { NextFunction, Request, Response } from 'express';

/** Papéis da equipe que podem acionar as rotas HTTP que gravam dados. */
export const STAFF_WRITE_ROLES = ['admin', 'estoquista'];

export interface AuthDeps {
  /** Verifica o ID token do Firebase Auth e devolve o uid (lança se for inválido). */
  verifyToken: (token: string) => Promise<{ uid: string }>;
  /** Perfil do usuário em `users/{uid}` (ou undefined se não existir). */
  loadProfile: (uid: string) => Promise<{ role?: string; isActive?: boolean } | undefined>;
}

/**
 * Middleware: exige `Authorization: Bearer <ID token>` de um administrador ou estoquista
 * ATIVO (auditoria A14). As rotas usam o Admin SDK, que ignora as regras do Firestore —
 * por isso a autorização precisa acontecer aqui.
 */
export function requireActiveStaff(deps: AuthDeps) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const header = req.header('authorization') ?? '';
    const match = /^Bearer (.+)$/i.exec(header);
    if (!match) {
      res.status(401).json({ error: 'Autenticação necessária.' });
      return;
    }
    let uid: string;
    try {
      uid = (await deps.verifyToken(match[1])).uid;
    } catch {
      res.status(401).json({ error: 'Sessão inválida ou expirada.' });
      return;
    }
    const profile = await deps.loadProfile(uid);
    if (!profile || profile.isActive !== true || !STAFF_WRITE_ROLES.includes(profile.role ?? '')) {
      res.status(403).json({ error: 'Sem permissão para esta operação.' });
      return;
    }
    res.locals.uid = uid;
    next();
  };
}

/** Texto obrigatório, sem espaços nas pontas, com tamanho máximo. */
export function cleanText(value: unknown, max = 200): string | null {
  if (typeof value !== 'string') return null;
  const t = value.trim();
  return t.length === 0 || t.length > max ? null : t;
}

/** Inteiro não negativo dentro de um limite razoável. */
export function cleanInt(value: unknown, max = 1_000_000): number | null {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 && value <= max
    ? value
    : null;
}
