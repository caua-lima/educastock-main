// Auditoria legível: sem mapas crus ("{quantity: 0}") nem códigos ("donation_recebida").
import 'package:educastock/features/audit/domain/texto_auditoria.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nome da ação em português', () {
    expect(rotuloAcao('entrada'), 'Entrada registrada');
    expect(rotuloAcao('donation_recebida'), 'Doação recebida');
    expect(rotuloAcao('algo_novo'), 'Algo novo');
  });

  test('mudança descrita campo a campo', () {
    expect(descreverMudanca({'quantity': 0}, {'quantity': 13}), 'Quantidade: de 0 para 13');
    expect(descreverMudanca({'status': 'pendente'}, {'status': 'recebida'}), 'Status: de pendente para recebida');
    expect(descreverMudanca(null, {'role': 'admin', 'isActive': true}), 'Papel: administrador · Ativo: sim');
    expect(descreverMudanca({'quantity': 5, 'status': 'disponivel'}, {'quantity': 0, 'status': 'distribuido'}),
        'Quantidade: de 5 para 0 · Status: de disponível para distribuído');
    expect(descreverMudanca(null, null), '');
  });
}
