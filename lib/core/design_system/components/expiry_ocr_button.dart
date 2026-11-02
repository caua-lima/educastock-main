import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../utils/expiry_date_parser.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class ExpiryOcrButton extends StatefulWidget {
  final void Function(DateTime date) onDateSuggested;

  const ExpiryOcrButton({super.key, required this.onDateSuggested});

  @override
  State<ExpiryOcrButton> createState() => _ExpiryOcrButtonState();
}

class _ExpiryOcrButtonState extends State<ExpiryOcrButton> {
  bool _loading = false;

  /// A leitura de texto (ML Kit) só existe no Android e no iOS.
  bool get _ocrSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickAndOcr() async {
    if (!_ocrSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A leitura da validade pela câmera funciona no app Android/iOS. '
            'Aqui, informe a data manualmente.',
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizer = TextRecognizer();
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final dates = extractExpiryDates(result.text);
      if (!mounted) return;

      if (dates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não encontrei uma data de validade. Aproxime a câmera da data impressa e tente de novo.',
            ),
          ),
        );
        return;
      }

      DateTime? chosen;
      if (dates.length == 1) {
        chosen = dates.first;
      } else {
        chosen = await showDialog<DateTime>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Selecione a data de validade'),
            children: dates.map((d) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d),
                child: Text(DateFormat('dd/MM/yyyy').format(d)),
              );
            }).toList(),
          ),
        );
      }

      if (chosen == null || !mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar data lida'),
          content: Text(
            'Data identificada: ${DateFormat('dd/MM/yyyy').format(chosen!)}\n\nConfirma esta data de validade?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Corrigir'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        widget.onDateSuggested(chosen);
      }
    } catch (e) {
      debugPrint('[OCR] erro ao ler validade: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não consegui ler a imagem. Tente de novo ou digite a data.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _pickAndOcr,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt_rounded, size: 18),
        label: Text(
          _loading ? 'Lendo...' : 'Ler validade',
          style: AppTypography.labelMedium,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandPrimary600,
          side: const BorderSide(color: AppColors.brandPrimary600),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
      ),
    );
  }
}
