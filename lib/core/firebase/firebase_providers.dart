import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instância única do Firestore usada por todas as fontes de dados do app.
///
/// Antes cada datasource chamava `FirebaseFirestore.instance` por conta própria; agora todas
/// recebem a instância por aqui. Nos testes, um único override troca o banco inteiro por um
/// Firestore falso (`fake_cloud_firestore`) — é isso que permite abrir as telas em testes de
/// layout sem Firebase de verdade.
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
