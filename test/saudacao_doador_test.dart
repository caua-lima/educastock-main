// Saudação do portal do doador: pessoa pelo primeiro nome, empresa pelo nome sem "Ltda".
import 'package:educastock/features/donations/domain/entities/donor_profile.dart';
import 'package:educastock/features/donations/presentation/pages/donor_home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pessoa física: primeiro nome', () {
    expect(nomeNaSaudacao('Luciana Prado Nogueira', null, DonorType.pf), 'Luciana');
    expect(nomeNaSaudacao(null, 'João Ricardo', null), 'João');
    expect(nomeNaSaudacao('  ', '', null), 'doador');
    expect(nomeNaSaudacao('Maria de Sa', null, null), 'Maria');
  });

  test('empresa: nome sem o sufixo da razão social', () {
    expect(nomeNaSaudacao('Supermercado Boa Compra Ltda', null, null), 'Supermercado Boa Compra');
    expect(nomeNaSaudacao('Padaria Pão Quente LTDA.', null, DonorType.pf), 'Padaria Pão Quente');
    expect(nomeNaSaudacao('Atacadão Alimentos S.A.', null, null), 'Atacadão Alimentos');
    expect(nomeNaSaudacao('Mercado Central', null, DonorType.pj), 'Mercado Central');
  });
}
