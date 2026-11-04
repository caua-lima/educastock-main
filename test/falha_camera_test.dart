// Cada falha de câmera tem motivo próprio (reauditoria R07): antes toda falha
// final aparecia como "permita o acesso à câmera".
import 'package:educastock/features/scanner/domain/falha_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

MobileScannerException _web(String domException, MobileScannerErrorCode code) => MobileScannerException(
      errorCode: code,
      errorDetails: MobileScannerErrorDetails(message: '$domException: mensagem do navegador'),
    );

void main() {
  test('erros reais do navegador (texto do DOMException) viram o motivo certo', () {
    expect(classificarFalhaCamera(_web('NotAllowedError', MobileScannerErrorCode.permissionDenied)), FalhaCamera.permissaoNegada);
    expect(classificarFalhaCamera(_web('NotFoundError', MobileScannerErrorCode.unsupported)), FalhaCamera.semCamera);
    expect(classificarFalhaCamera(_web('NotReadableError', MobileScannerErrorCode.genericError)), FalhaCamera.ocupada);
    expect(classificarFalhaCamera(_web('NotSupportedError', MobileScannerErrorCode.unsupported)), FalhaCamera.naoSuportada);
    expect(classificarFalhaCamera(Exception('algo inesperado')), FalhaCamera.desconhecida);
  });

  test('só falhas passageiras são repetidas sozinhas; todas têm título e explicação', () {
    expect(FalhaCamera.ocupada.repetirAutomaticamente, isTrue);
    expect(FalhaCamera.permissaoNegada.repetirAutomaticamente, isFalse);
    expect(FalhaCamera.semCamera.repetirAutomaticamente, isFalse);
    for (final f in FalhaCamera.values) {
      expect(f.titulo, isNotEmpty);
      expect(f.explicacao, isNotEmpty);
    }
  });
}
