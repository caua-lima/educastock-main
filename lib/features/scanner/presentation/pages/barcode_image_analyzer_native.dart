import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Analisa uma imagem estática com Google ML Kit e retorna o primeiro barcode.
/// Prefere EAN-13 / UPC-A / Code-128 (formatos de produto). Retorna null se
/// nenhum barcode for encontrado ou em caso de erro.
Future<String?> analyzeBarcodeImage(String path) async {
  final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
  try {
    final barcodes = await scanner.processImage(InputImage.fromFilePath(path));
    if (barcodes.isEmpty) return null;

    // Prefere formatos de produto (EAN/UPC/Code-128) sobre QR Code
    final hit = barcodes.firstWhere(
      (b) =>
          b.format == BarcodeFormat.ean13 ||
          b.format == BarcodeFormat.ean8 ||
          b.format == BarcodeFormat.upca ||
          b.format == BarcodeFormat.code128 ||
          b.format == BarcodeFormat.code39 ||
          b.format == BarcodeFormat.itf,
      orElse: () => barcodes.first,
    );
    return hit.rawValue;
  } catch (_) {
    return null;
  } finally {
    await scanner.close();
  }
}
