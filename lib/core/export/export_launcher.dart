import 'package:flutter/widgets.dart';

import 'export_sheet.dart' deferred as sheet;
import 'report_table.dart';

/// Abre a folha "Exportar relatório" (PDF, Excel, CSV).
///
/// O módulo de exportação (bibliotecas de PDF, Excel e impressão) é carregado só na
/// primeira vez que alguém exporta. Na web isso tira esse código do carregamento inicial
/// do app; no celular o carregamento é imediato.
Future<void> showExportSheet(
  BuildContext context, {
  required Future<ReportTable> Function() loader,
}) async {
  await sheet.loadLibrary();
  if (!context.mounted) return;
  await sheet.showExportSheet(context, loader: loader);
}
