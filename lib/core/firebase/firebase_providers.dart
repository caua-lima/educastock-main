import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instância única do Firestore usada por todas as fontes de dados do app.
///
/// Antes cada datasource chamava `FirebaseFirestore.instance` por conta própria; agora todas
/// recebem a instância por aqui. Nos testes, um único override troca o banco inteiro por um
/// Firestore falso (`fake_cloud_firestore`) — é isso que permite abrir as telas em testes de
/// layout sem Firebase de verdade.
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// Firestore para as fontes de dados, ligado a quem está logado.
///
/// Cada fonte de dados é criada por aqui e passa a ser outra quando a pessoa logada muda;
/// com isso as leituras são abertas de novo com a credencial certa. Sem isso, uma leitura
/// aberta na sessão anterior (ou antes do login) falhava por permissão e ficava presa em
/// erro: sair do administrador e entrar como estoquista mostrava "sem permissão".
FirebaseFirestore bancoDaSessao(Ref ref) {
  // Na web o app recomeça no login ao sair (recomecarNoLogin): reabrir todas as leituras
  // de uma vez lá provoca uma falha interna do SDK web do Firestore.
  if (!kIsWeb) ref.watch(sessaoUidProvider.select((s) => s.valueOrNull));
  return ref.watch(firestoreProvider);
}

/// Quem está logado (só o uid), direto do Firebase Auth: sem passar pelo Firestore,
/// para não criar dependência circular com o login.
///
/// O aviso sai meio segundo depois da troca: no instante do login o Firestore ainda está
/// trocando as credenciais, e uma leitura aberta nessa hora volta "sem permissão". Só
/// avisa quando a pessoa muda de fato (distinct). Sem Firebase (testes), nunca muda.
final sessaoUidProvider = StreamProvider<String?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance
      .authStateChanges()
      .map((u) => u?.uid)
      .asyncMap((uid) async {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return uid;
      })
      .distinct();
});

/// Projeto Firebase em uso. Separa a fila offline por projeto: uma pendência criada
/// num ambiente nunca é enviada para outro.
final firebaseProjectIdProvider = Provider<String>((ref) {
  try {
    return ref.watch(firestoreProvider).app.options.projectId;
  } catch (_) {
    return 'desconhecido';
  }
});
