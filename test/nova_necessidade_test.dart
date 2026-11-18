// Nova necessidade da ONG: validação e o documento gravado.
import 'package:educastock/features/donations/domain/entities/donation_need.dart';
import 'package:educastock/features/donations/domain/nova_necessidade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const leite = NovaNecessidade(
    titulo: '  Leite integral ',
    categoria: 'alimento',
    unidade: 'un',
    quantidade: 120,
    prioridade: NeedPriority.critica,
    validadeMinimaDias: 45,
    observacao: ' Caixas de 1 L ',
  );

  test('necessidade válida não tem problemas', () {
    expect(leite.problemas(), isEmpty);
  });

  test('aponta nome curto, quantidade zero e validade fora da faixa', () {
    const ruim = NovaNecessidade(
      titulo: 'Le',
      categoria: 'alimento',
      unidade: 'un',
      quantidade: 0,
      prioridade: NeedPriority.normal,
      validadeMinimaDias: -1,
    );
    expect(ruim.problemas(), hasLength(3));
  });

  test('documento: manual, ativo, sem promessas e com o restante igual à meta', () {
    final d = leite.dados(criadoPor: 'u-admin');
    expect(d['source'], 'manual');
    expect(d['title'], 'Leite integral');
    expect(d['priority'], 'critica');
    expect(d['priorityRank'], 1);
    expect(d['suggestedQty'], 120);
    expect(d['pledgedQty'], 0);
    expect(d['remainingQty'], 120);
    expect(d['isActive'], true);
    expect(d['productId'], isNull);
    expect(d['note'], 'Caixas de 1 L');
    expect(d['createdBy'], 'u-admin');
    // Lido de volta como o doador vê:
    final n = DonationNeed.fromMap({...d, 'updatedAt': null}, 'n1');
    expect(n.title, 'Leite integral');
    expect(n.remainingQty, 120);
    expect(n.priority, NeedPriority.critica);
  });
}
