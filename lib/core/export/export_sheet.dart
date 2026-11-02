import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import 'report_exporter.dart';
import 'report_table.dart';

/// Abre a folha "Exportar relatório" com PDF, Excel, CSV ou os três de uma vez.
///
/// [loader] só roda quando o usuário escolhe um formato, então a tabela (que pode
/// precisar ler dados) não é montada à toa.
Future<void> showExportSheet(
  BuildContext context, {
  required Future<ReportTable> Function() loader,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ExportSheet(loader: loader, hostContext: context),
  );
}

class _ExportSheet extends StatefulWidget {
  final Future<ReportTable> Function() loader;
  final BuildContext hostContext;
  const _ExportSheet({required this.loader, required this.hostContext});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String? _busy; // id do formato em andamento

  Future<void> _run(String id, Future<void> Function(ReportTable) action) async {
    setState(() => _busy = id);
    final host = widget.hostContext;
    try {
      final table = await widget.loader();
      await action(table);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (host.mounted) {
        showCasaSnackbar(host, message: 'Relatório exportado!', isSuccess: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = null);
      showCasaSnackbar(context,
          message: 'Não foi possível exportar. Tente novamente.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = <({String id, IconData icon, String title, String subtitle, Future<void> Function(ReportTable) action})>[
      (
        id: 'pdf',
        icon: Icons.picture_as_pdf_rounded,
        title: 'PDF',
        subtitle: 'Documento pronto para imprimir ou enviar',
        action: ReportExporter.sharePdf,
      ),
      (
        id: 'xlsx',
        icon: Icons.table_chart_rounded,
        title: 'Excel (.xlsx)',
        subtitle: 'Planilha para filtrar e calcular',
        action: ReportExporter.shareXlsx,
      ),
      (
        id: 'csv',
        icon: Icons.description_outlined,
        title: 'CSV',
        subtitle: 'Texto separado por ponto e vírgula (abre no Excel)',
        action: ReportExporter.shareCsv,
      ),
      (
        id: 'all',
        icon: Icons.folder_zip_outlined,
        title: 'Os três formatos',
        subtitle: 'PDF, Excel e CSV gerados ao mesmo tempo',
        action: ReportExporter.shareAll,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exportar relatório',
                style: AppTypography.headingMedium.copyWith(color: cs.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            for (final o in options)
              ListTile(
                enabled: _busy == null,
                leading: _busy == o.id
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(o.icon, color: AppColors.brandPrimary600),
                title: Text(o.title, style: AppTypography.labelLarge),
                subtitle: Text(o.subtitle),
                onTap: () => _run(o.id, o.action),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
