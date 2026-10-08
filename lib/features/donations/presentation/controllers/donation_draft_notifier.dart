import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../domain/donation_validators.dart';
import '../../domain/entities/donation.dart';
import '../../domain/entities/donation_item.dart';
import '../../domain/entities/donation_need.dart';
import '../../domain/entities/donation_rules.dart';
import 'donation_needs_provider.dart';

/// Estado local do formulário de doação (D06–D07): itens já adicionados, o
/// item em edição, ponto, janela e aceite dos termos. Persistido localmente
/// para sobreviver a fechamento do app ou falta de conexão (RNF18).
@immutable
class DonationDraft {
  /// Gerado uma vez por rascunho: vira o ID do documento (reenvio idempotente).
  final String clientId;
  final List<DonationItem> items;
  final DonationItem? editing;

  /// Posição do item em edição na lista; null quando é um item novo.
  final int? editingIndex;
  final String? pointId;
  final DonationWindow? window;
  final bool termsAccepted;

  const DonationDraft({
    required this.clientId,
    this.items = const [],
    this.editing,
    this.editingIndex,
    this.pointId,
    this.window,
    this.termsAccepted = false,
  });

  factory DonationDraft.empty() => DonationDraft(clientId: const Uuid().v4());

  bool get isEmpty => items.isEmpty && editing == null && pointId == null;

  DonationDraft copyWith({
    List<DonationItem>? items,
    DonationItem? editing,
    bool clearEditing = false,
    int? editingIndex,
    String? pointId,
    DonationWindow? window,
    bool clearWindow = false,
    bool? termsAccepted,
  }) =>
      DonationDraft(
        clientId: clientId,
        items: items ?? this.items,
        editing: clearEditing ? null : (editing ?? this.editing),
        editingIndex: clearEditing ? null : (editingIndex ?? this.editingIndex),
        pointId: pointId ?? this.pointId,
        window: clearWindow ? null : (window ?? this.window),
        termsAccepted: termsAccepted ?? this.termsAccepted,
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'items': items.map((i) => i.toJson()).toList(),
        'pointId': pointId,
        'window': window?.toJson(),
      };

  factory DonationDraft.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final rawWindow = json['window'];
    return DonationDraft(
      clientId: json['clientId'] as String? ?? const Uuid().v4(),
      items: rawItems
          .whereType<Map>()
          .map((e) => DonationItem.fromMap(e.cast<String, dynamic>()))
          .toList(),
      pointId: json['pointId'] as String?,
      window: rawWindow is Map
          ? DonationWindow.fromMap(rawWindow.cast<String, dynamic>())
          : null,
    );
  }
}

/// Gerencia o rascunho da doação. Regras de negócio (RN-D03 etc.) ficam em
/// `validateDonationItem` / `validateDonationDraft`; aqui só há estado.
class DonationDraftNotifier extends Notifier<DonationDraft> {
  @override
  DonationDraft build() => DonationDraft.empty();

  String get _prefsKey =>
      'donation_draft_v1_${ref.read(currentUserProvider)?.id ?? 'anon'}';

  // ─── Persistência local ────────────────────────────────────────────────────

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = DonationDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[DonationDraft] restore error: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
      }
    } catch (e) {
      debugPrint('[DonationDraft] persist error: $e');
    }
  }

  void _set(DonationDraft next) {
    state = next;
    _persist();
  }

  /// Descarta tudo (após confirmar a doação ou ao desistir).
  Future<void> clear() async {
    state = DonationDraft.empty();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugPrint('[DonationDraft] clear error: $e');
    }
  }

  // ─── Itens ─────────────────────────────────────────────────────────────────

  /// Passo 1 → 2 a partir de uma necessidade: item pré-preenchido.
  void startFromNeed(DonationNeed need) {
    final suggested = need.remainingQty > 24 ? 24 : need.remainingQty;
    // Zera o índice de edição: é sempre um item novo.
    _set(state.copyWith(clearEditing: true).copyWith(
      editing: DonationItem(
        needId: need.id,
        category: need.categoryId,
        description: need.title,
        quantity: suggested < 1 ? 1 : suggested,
        unit: need.unit,
        hasExpiry: _perishableCategories.contains(need.categoryId),
      ),
    ));
  }

  /// Oferta espontânea: o doador descreve o item.
  void startCustom() {
    _set(state.copyWith(clearEditing: true).copyWith(
      editing: const DonationItem(
        category: 'alimento',
        description: '',
        quantity: 1,
        hasExpiry: true,
      ),
    ));
  }

  /// Reabre um item já adicionado para edição.
  void editItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    _set(state.copyWith(editing: state.items[index], editingIndex: index));
  }

  void updateEditing(DonationItem item) {
    if (state.editing == null) return;
    _set(state.copyWith(editing: item));
  }

  /// Descarta o item em edição sem adicioná-lo.
  void cancelEditing() => _set(state.copyWith(clearEditing: true));

  /// Valida (RN-D03) e adiciona/atualiza o item em edição na lista.
  /// Retorna a mensagem de erro que bloqueia, ou null quando adicionou.
  String? commitEditing(DonationRules rules, {DonationNeed? need}) {
    final editing = state.editing;
    if (editing == null) return 'Nenhum item em edição.';

    final index = state.editingIndex;
    final isNew = index == null;
    if (isNew && state.items.length >= rules.maxItems) {
      return 'Máximo de ${rules.maxItems} itens por doação.';
    }

    final result = validateDonationItem(
      editing,
      rules: rules,
      need: need,
      referenceDate: state.window?.from,
    );
    if (!result.isValid) return result.error;

    final committed = editing.copyWith(subjectToReview: result.subjectToReview);
    final items = [...state.items];
    if (index == null) {
      items.add(committed);
    } else {
      items[index] = committed;
    }
    _set(state.copyWith(items: items, clearEditing: true));
    return null;
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final items = [...state.items]..removeAt(index);
    _set(state.copyWith(items: items));
  }

  // ─── Entrega e termos ──────────────────────────────────────────────────────

  void setPoint(String pointId) => _set(state.copyWith(pointId: pointId));

  void setWindow(DonationWindow? window) => _set(
        window == null ? state.copyWith(clearWindow: true) : state.copyWith(window: window),
      );

  void setTermsAccepted(bool accepted) =>
      state = state.copyWith(termsAccepted: accepted);
}

final donationDraftProvider =
    NotifierProvider<DonationDraftNotifier, DonationDraft>(DonationDraftNotifier.new);

/// Categorias que costumam ter validade (alimento e bebida).
const Set<String> _perishableCategories = {'alimento', 'bebida'};

bool categoryUsuallyPerishable(String categoryId) =>
    _perishableCategories.contains(categoryId);

/// Necessidade de origem do item em edição (para validar contra a meta dela).
final editingNeedProvider = Provider<DonationNeed?>((ref) {
  final needId = ref.watch(donationDraftProvider.select((d) => d.editing?.needId));
  if (needId == null) return null;
  return ref.watch(needsByIdProvider)[needId];
});
