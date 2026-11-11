import 'entities/donation_need.dart';

/// O que a equipe preenche para publicar uma necessidade da ONG (ex.: "Leite integral",
/// 120 un, crítica). Vira um documento `donation_needs` com `source: manual`.
class NovaNecessidade {
  final String titulo;
  final String categoria; // ProductCategory.name
  final String unidade;
  final int quantidade;
  final NeedPriority prioridade;
  final int validadeMinimaDias;
  final String? produtoId;
  final String? observacao;

  const NovaNecessidade({
    required this.titulo,
    required this.categoria,
    required this.unidade,
    required this.quantidade,
    required this.prioridade,
    this.validadeMinimaDias = 0,
    this.produtoId,
    this.observacao,
  });

  /// Problemas que impedem publicar, um por campo (lista vazia = pode publicar).
  List<String> problemas() => [
        if (titulo.trim().length < 3)
          'Informe o nome do item (pelo menos 3 letras).',
        if (titulo.trim().length > 80)
          'O nome do item pode ter no máximo 80 letras.',
        if (unidade.trim().isEmpty) 'Escolha a unidade.',
        if (quantidade <= 0) 'A quantidade precisa ser maior que zero.',
        if (quantidade > 100000)
          'A quantidade parece alta demais: confira o número.',
        if (validadeMinimaDias < 0 || validadeMinimaDias > 3650)
          'A validade mínima deve ficar entre 0 e 3650 dias.',
        if ((observacao ?? '').trim().length > 200)
          'A observação pode ter no máximo 200 letras.',
      ];

  /// Campos gravados no Firestore (sem as datas, que o servidor preenche).
  Map<String, dynamic> dados({required String criadoPor}) {
    final nota = observacao?.trim();
    final produto = produtoId?.trim();
    return {
      'source': NeedSource.manual.value,
      'productId': (produto == null || produto.isEmpty) ? null : produto,
      'categoryId': categoria,
      'title': titulo.trim(),
      'unit': unidade.trim(),
      'priority': prioridade.value,
      'priorityRank': prioridade.rank,
      'suggestedQty': quantidade,
      'pledgedQty': 0,
      'remainingQty': quantidade,
      'minShelfLifeDays': validadeMinimaDias,
      'validUntil': null,
      'isActive': true,
      'note': (nota == null || nota.isEmpty) ? null : nota,
      'createdBy': criadoPor,
    };
  }
}
