import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  // Regex patterns for common Brazilian expiry date formats on packaging
  static final _datePatterns = [
    RegExp(r'\b(\d{2})[/\-\.](\d{2})[/\-\.](\d{4})\b'), // DD/MM/AAAA
    RegExp(r'\b(\d{2})[/\-\.](\d{4})\b'), // MM/AAAA
    RegExp(r'\b(\d{2})\s+(\d{2})\s+(\d{4})\b'), // DD MM AAAA
    RegExp(r'\b(\d{2})\s+(\d{4})\b'), // MM AAAA
  ];

  List<DateTime> _extractDates(String text) {
    final found = <DateTime>[];
    final now = DateTime.now();

    // Pattern DD/MM/YYYY
    for (final m in _datePatterns[0].allMatches(text)) {
      try {
        final d = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        final dt = DateTime(y, mo, d);
        if (dt.isAfter(now.subtract(const Duration(days: 1)))) found.add(dt);
      } catch (_) {}
    }
    // Pattern MM/YYYY
    for (final m in _datePatterns[1].allMatches(text)) {
      try {
        final mo = int.parse(m.group(1)!);
        final y = int.parse(m.group(2)!);
        if (mo >= 1 && mo <= 12) {
          final dt = DateTime(y, mo, 28);
          if (dt.isAfter(now.subtract(const Duration(days: 1)))) found.add(dt);
        }
      } catch (_) {}
    }
    return found;
  }

  Future<void> _pickAndOcr() async {
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

      final dates = _extractDates(result.text);
      if (!mounted) return;

      if (dates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma data encontrada na imagem.')),
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
        widget.onDateSuggested(chosen!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar imagem: $e')),
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
