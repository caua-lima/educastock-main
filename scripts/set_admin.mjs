/**
 * Script para promover um usuário a administrador no Firestore.
 * 
 * Pré-requisito:
 *   - Ter o Firebase CLI instalado e autenticado: firebase login
 *   - Ou definir GOOGLE_APPLICATION_CREDENTIALS com o caminho de uma service account
 * 
 * Uso:
 *   node scripts/set_admin.mjs <email-do-usuario>
 * 
 * Exemplo:
 *   node scripts/set_admin.mjs admin@casadacrianca.org.br
 */

import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const email = process.argv[2];

if (!email) {
  console.error('\n❌  Informe o e-mail do usuário:\n');
  console.error('    node scripts/set_admin.mjs <email>\n');
  process.exit(1);
}

// Inicializa o app usando as credenciais padrão (GOOGLE_APPLICATION_CREDENTIALS)
// ou Application Default Credentials (firebase login --reauth)
if (!getApps().length) {
  initializeApp();
}

const auth = getAuth();
const db = getFirestore();

try {
  console.log(`\n🔍  Buscando usuário com e-mail: ${email}...`);
  const user = await auth.getUserByEmail(email);
  console.log(`✅  Usuário encontrado: ${user.uid} (${user.displayName ?? 'sem nome'})`);

  const ref = db.collection('users').doc(user.uid);
  await ref.set(
    {
      role: 'admin',
      isActive: true,
      updatedAt: new Date().toISOString(),
    },
    { merge: true }
  );

  console.log(`\n🎉  Usuário ${email} promovido a administrador com sucesso!`);
  console.log(`    uid: ${user.uid}`);
  console.log(`    role: admin`);
  console.log(`    isActive: true\n`);
} catch (err) {
  if (err.code === 'auth/user-not-found') {
    console.error(`\n❌  Nenhum usuário encontrado com o e-mail: ${email}`);
    console.error('    Verifique se o usuário já realizou o primeiro login no app.\n');
  } else {
    console.error('\n❌  Erro inesperado:', err.message, '\n');
  }
  process.exit(1);
}
