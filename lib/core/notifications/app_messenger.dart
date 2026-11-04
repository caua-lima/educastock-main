import 'package:flutter/material.dart';

/// Mensageiro global do app (avisos em SnackBar fora de um BuildContext, ex.: push
/// recebido com o app aberto). Ligado ao `MaterialApp.router` em `main.dart`.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
