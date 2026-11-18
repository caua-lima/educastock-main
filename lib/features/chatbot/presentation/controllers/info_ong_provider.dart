import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../domain/info_ong.dart';

/// Dados da Casa da Criança que o assistente usa (`settings/ong_info`). Sem o documento
/// ou sem permissão de leitura, ficam os dados públicos padrão.
final infoOngProvider = StreamProvider<InfoOng>((ref) {
  return bancoDaSessao(ref)
      .collection('settings')
      .doc('ong_info')
      .snapshots()
      .map((d) => InfoOng.fromMap(d.data()));
});
