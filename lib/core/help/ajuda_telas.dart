// Ajuda curta de cada tela: para que serve, ações principais e dúvidas
// frequentes. Abre antes do tutorial — quem só tem uma dúvida simples não
// precisa passar pelo passo a passo. Textos fiéis ao que a tela mostra.

import 'package:flutter/material.dart';

import '../design_system/components/casa_help_modal.dart';
import '../router/app_router.dart';

class AjudaTela {
  final String titulo;
  final String finalidade;
  final IconData icone;
  final List<HelpTip> acoes;
  final List<HelpFaq> duvidas;
  const AjudaTela({
    required this.titulo,
    required this.finalidade,
    this.icone = Icons.help_outline_rounded,
    this.acoes = const [],
    this.duvidas = const [],
  });
}

const _validadeDiaCivil = HelpFaq(
  pergunta: 'Um lote que vence hoje já está vencido?',
  resposta: 'Não. O produto vale até o fim do dia impresso na embalagem; passa a contar como vencido a partir do dia seguinte.',
);

const _semPermissao = HelpFaq(
  pergunta: 'Não vejo um botão que outra pessoa vê.',
  resposta: 'Algumas ações dependem do perfil de acesso (administrador, estoquista, voluntário ou consulta). Fale com quem administra o sistema.',
);

const Map<String, AjudaTela> _porRota = {
  AppRoutes.dashboard: AjudaTela(
    titulo: 'Painel',
    finalidade: 'Resumo do estoque: indicadores, atalhos e o que precisa de atenção esta semana.',
    icone: Icons.dashboard_rounded,
    acoes: [
      HelpTip(icon: Icons.insights_rounded, title: 'Indicadores', description: 'Totais de produtos, lotes e alertas do estoque.'),
      HelpTip(icon: Icons.qr_code_scanner_rounded, title: 'Escanear', description: 'Dá entrada ou consulta um produto pelo código de barras.'),
      HelpTip(icon: Icons.warning_amber_rounded, title: 'Alertas críticos', description: 'Lotes vencidos ou perto de vencer, os mais urgentes primeiro.'),
    ],
    duvidas: [
      HelpFaq(pergunta: 'Um indicador mostra "—".', resposta: 'Os dados não carregaram (internet ou permissão). Use "Tentar de novo" no aviso; "—" nunca significa zero.'),
      _validadeDiaCivil,
    ],
  ),
  AppRoutes.productList: AjudaTela(
    titulo: 'Estoque',
    finalidade: 'Todos os produtos do catálogo com o saldo atual e a situação de validade.',
    icone: Icons.inventory_2_rounded,
    acoes: [
      HelpTip(icon: Icons.search_rounded, title: 'Buscar', description: 'Por nome, marca ou código de barras.'),
      HelpTip(icon: Icons.filter_list_rounded, title: 'Filtrar e ordenar', description: 'Por categoria, situação ou nome.'),
      HelpTip(icon: Icons.touch_app_rounded, title: 'Abrir produto', description: 'Mostra os lotes, a localização e o histórico.'),
    ],
    duvidas: [
      HelpFaq(pergunta: 'O produto aparece sem estoque, mas tem lote.', resposta: 'Confira se o lote foi distribuído ou se a lista ainda está carregando. Se houver aviso de erro, toque em "Tentar de novo".'),
      _semPermissao,
    ],
  ),
  AppRoutes.productForm: AjudaTela(
    titulo: 'Cadastro de produto',
    finalidade: 'Cria ou edita um produto do catálogo. Os lotes (quantidade e validade) são cadastrados depois, no produto.',
    icone: Icons.edit_note_rounded,
    acoes: [
      HelpTip(icon: Icons.label_rounded, title: 'Nome e categoria', description: 'Use o nome como aparece na embalagem.'),
      HelpTip(icon: Icons.event_rounded, title: 'Perecível', description: 'Marque se o produto tem data de validade.'),
    ],
    duvidas: [
      HelpFaq(pergunta: 'Os dados vieram preenchidos da internet.', resposta: 'São sugestões das bases públicas. Confira e corrija antes de salvar.'),
    ],
  ),
  AppRoutes.batchForm: AjudaTela(
    titulo: 'Novo lote',
    finalidade: 'Registra a entrada de unidades de um produto, com validade, origem e local.',
    icone: Icons.add_box_rounded,
    acoes: [
      HelpTip(icon: Icons.numbers_rounded, title: 'Quantidade', description: 'Unidades que estão entrando agora.'),
      HelpTip(icon: Icons.event_rounded, title: 'Validade', description: 'Digite ou leia a data da embalagem com a câmera.'),
      HelpTip(icon: Icons.place_rounded, title: 'Local', description: 'Onde o lote fica guardado, para achar depois.'),
    ],
    duvidas: [_validadeDiaCivil],
  ),
  AppRoutes.movement: AjudaTela(
    titulo: 'Distribuição',
    finalidade: 'Registra a saída de itens do estoque, por produto ou por receita.',
    icone: Icons.outbox_rounded,
    acoes: [
      HelpTip(icon: Icons.checklist_rounded, title: 'Escolher itens', description: 'Selecione produtos e quantidades, ou uma receita.'),
      HelpTip(icon: Icons.sort_rounded, title: 'Ordem dos lotes', description: 'O sistema sugere primeiro o lote que vence antes (FEFO).'),
      HelpTip(icon: Icons.check_circle_rounded, title: 'Confirmar', description: 'Só então o estoque é baixado.'),
    ],
    duvidas: [
      HelpFaq(pergunta: 'Posso distribuir um lote vencido?', resposta: 'O sistema mostra o aviso de vencido e pede confirmação. Confira a política da instituição: lote vencido normalmente vai para descarte, não para distribuição.'),
      HelpFaq(pergunta: 'E se a internet cair?', resposta: 'A saída fica guardada no aparelho e é enviada quando a conexão voltar, sempre na mesma conta.'),
    ],
  ),
  AppRoutes.history: AjudaTela(
    titulo: 'Histórico',
    finalidade: 'Todas as entradas, saídas e ajustes registrados, com quem fez e quando.',
    icone: Icons.history_rounded,
    acoes: [
      HelpTip(icon: Icons.filter_list_rounded, title: 'Filtrar', description: 'Por tipo de movimentação e período.'),
    ],
  ),
  AppRoutes.alerts: AjudaTela(
    titulo: 'Alertas de validade',
    finalidade: 'Lotes vencidos ou perto de vencer, em ordem de urgência.',
    icone: Icons.notifications_active_rounded,
    acoes: [
      HelpTip(icon: Icons.filter_alt_rounded, title: 'Filtrar por urgência', description: 'Vencidos, críticos ou em atenção.'),
    ],
    duvidas: [
      _validadeDiaCivil,
      HelpFaq(pergunta: 'Como mudar os prazos dos alertas?', resposta: 'Em Configurações › Alertas (quem tem permissão).'),
    ],
  ),
  AppRoutes.reports: AjudaTela(
    titulo: 'Relatórios',
    finalidade: 'Gráficos e resumos do estoque e das movimentações, com exportação.',
    icone: Icons.bar_chart_rounded,
    acoes: [
      HelpTip(icon: Icons.date_range_rounded, title: 'Período', description: 'Escolha o intervalo analisado.'),
      HelpTip(icon: Icons.download_rounded, title: 'Exportar', description: 'Gera PDF ou planilha com os mesmos dados da tela.'),
    ],
    duvidas: [
      HelpFaq(pergunta: 'O que é o índice de saúde do estoque?', resposta: 'Uma nota de 0 a 100: começa em 100 e perde pontos por lote vencido ou perto de vencer. Não é porcentagem do estoque.'),
      HelpFaq(pergunta: 'Um gráfico mostra erro.', resposta: 'Os dados não carregaram. Use "Tentar de novo"; o relatório nunca mostra zero no lugar de um erro.'),
    ],
  ),
  AppRoutes.audit: AjudaTela(
    titulo: 'Auditoria',
    finalidade: 'Registro imutável de quem fez o quê no sistema.',
    icone: Icons.fact_check_rounded,
    acoes: [
      HelpTip(icon: Icons.filter_list_rounded, title: 'Filtrar', description: 'Por pessoa, ação ou período.'),
      HelpTip(icon: Icons.table_view_rounded, title: 'Exportar CSV', description: 'Para conferência fora do sistema.'),
    ],
  ),
  AppRoutes.locations: AjudaTela(
    titulo: 'Locais',
    finalidade: 'Onde os lotes ficam guardados (depósito, prateleira, posição).',
    icone: Icons.place_rounded,
  ),
  AppRoutes.mlForecast: AjudaTela(
    titulo: 'Previsão de consumo',
    finalidade: 'Estimativa de consumo e sugestões de reposição calculadas a partir do histórico.',
    icone: Icons.trending_up_rounded,
    duvidas: [
      HelpFaq(pergunta: 'A previsão é exata?', resposta: 'É uma estimativa. Use como apoio e confira com a realidade da instituição.'),
    ],
  ),
  AppRoutes.mlInsights: AjudaTela(
    titulo: 'Análise de risco',
    finalidade: 'Lotes classificados por risco de perda, com ações sugeridas.',
    icone: Icons.insights_rounded,
  ),
  AppRoutes.recipes: AjudaTela(
    titulo: 'Receitas',
    finalidade: 'Receitas com os ingredientes do estoque, usadas para distribuir por receita.',
    icone: Icons.restaurant_menu_rounded,
  ),
  AppRoutes.settings: AjudaTela(
    titulo: 'Configurações',
    finalidade: 'Tema (claro, escuro ou do sistema), conta, usuárias, categorias e alertas.',
    icone: Icons.settings_rounded,
    duvidas: [
      HelpFaq(pergunta: 'O que é o tema "Sistema"?', resposta: 'Segue o modo claro/escuro do aparelho e muda junto com ele.'),
      _semPermissao,
    ],
  ),
  AppRoutes.usersManagement: AjudaTela(
    titulo: 'Usuárias e acessos',
    finalidade: 'Quem usa o sistema, o perfil de acesso de cada pessoa e se a conta está ativa.',
    icone: Icons.group_rounded,
    duvidas: [
      HelpFaq(pergunta: 'Desativar apaga a conta?', resposta: 'Não. A pessoa só deixa de acessar; o histórico dela continua registrado.'),
    ],
  ),
  AppRoutes.categoriesSettings: AjudaTela(
    titulo: 'Categorias',
    finalidade: 'Categorias usadas para organizar o catálogo.',
    icone: Icons.category_rounded,
  ),
  AppRoutes.alertsSettings: AjudaTela(
    titulo: 'Configurar alertas',
    finalidade: 'Prazos de aviso de vencimento (crítico e atenção) e notificações.',
    icone: Icons.tune_rounded,
    duvidas: [_validadeDiaCivil],
  ),
  AppRoutes.adjustmentApprovals: AjudaTela(
    titulo: 'Aprovação de ajustes',
    finalidade: 'Pedidos de correção de estoque que precisam de aprovação.',
    icone: Icons.rule_rounded,
  ),
  AppRoutes.productReview: AjudaTela(
    titulo: 'Revisão do produto',
    finalidade: 'Mostra se o código já está no cadastro. Se não estiver, procura sugestões em bases públicas para você cadastrar.',
    icone: Icons.fact_check_rounded,
    acoes: [
      HelpTip(icon: Icons.check_circle_rounded, title: 'Produto cadastrado', description: 'Adicione unidades a um lote existente ou crie um lote novo.'),
      HelpTip(icon: Icons.travel_explore_rounded, title: 'Pesquisa na internet', description: 'Só quando o código não está no cadastro. O resultado é uma sugestão para revisar.'),
      HelpTip(icon: Icons.add_box_rounded, title: 'Produto novo', description: 'Cadastre manualmente — dá para continuar mesmo sem internet.'),
    ],
    duvidas: [
      HelpFaq(pergunta: '"Consulta indisponível" é o mesmo que "não encontrado"?', resposta: 'Não. Indisponível = a internet ou a base falhou; tente de novo. Não encontrado = as bases responderam e não conhecem o código.'),
    ],
  ),
};

/// Ajuda da tela pelo caminho da rota (aceita caminhos com parâmetros, ex.:
/// /products/abc usa a ajuda de detalhe do produto).
AjudaTela? ajudaDaRota(String caminho) {
  final direto = _porRota[caminho];
  if (direto != null) return direto;
  if (caminho.startsWith('${AppRoutes.productList}/') && caminho != AppRoutes.productForm) {
    return const AjudaTela(
      titulo: 'Produto',
      finalidade: 'Detalhes do produto: lotes ativos, validade, localização e estatísticas.',
      icone: Icons.inventory_rounded,
      acoes: [
        HelpTip(icon: Icons.add_box_rounded, title: 'Adicionar lote', description: 'Registra uma entrada nova deste produto.'),
      ],
      duvidas: [_validadeDiaCivil],
    );
  }
  return null;
}
