import 'entities/donation_item.dart';
import 'entities/donation_need.dart';
import 'entities/donation_point.dart';
import 'entities/donation_rules.dart';

/// Resultado da validação de um item (RN-D03, RN-D05, RN-D06).
class ItemValidation {
  /// Mensagem de erro que BLOQUEIA o avanço; null quando o item é aceitável.
  final String? error;

  /// Validade abaixo do mínimo ou quantidade acima do restante a cobrir:
  /// não bloqueia, mas a doação segue "sujeita a avaliação" da equipe.
  final bool subjectToReview;

  /// Dias entre a data de referência e a validade (null se sem validade).
  final int? daysToExpiry;

  /// Mínimo de dias de validade exigido para este item.
  final int minShelfLifeDays;

  const ItemValidation({
    this.error,
    this.subjectToReview = false,
    this.daysToExpiry,
    this.minShelfLifeDays = 0,
  });

  bool get isValid => error == null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// RN-D03 (validade mínima), RN-D05 (excedente) e regras básicas do item.
///
/// [referenceDate] é a data prevista de entrega (início da janela); sem ela,
/// usa-se [now]. [need] é a necessidade de origem, quando existe.
ItemValidation validateDonationItem(
  DonationItem item, {
  required DonationRules rules,
  DonationNeed? need,
  DateTime? referenceDate,
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final reference = _dateOnly(referenceDate ?? today);
  final minDays = (need != null && need.minShelfLifeDays > 0)
      ? need.minShelfLifeDays
      : rules.minShelfLifeDays;

  if (item.description.trim().isEmpty) {
    return ItemValidation(
      error: 'Informe o que será doado.',
      minShelfLifeDays: minDays,
    );
  }
  if (rules.isCategoryBlocked(item.category)) {
    return ItemValidation(
      error: 'Esta categoria não é aceita pela ONG no momento.',
      minShelfLifeDays: minDays,
    );
  }
  if (item.quantity <= 0) {
    return ItemValidation(
      error: 'A quantidade deve ser maior que zero.',
      minShelfLifeDays: minDays,
    );
  }

  var subjectToReview = false;
  int? days;

  if (item.hasExpiry) {
    final expiry = item.expiryDate;
    if (expiry == null) {
      return ItemValidation(
        error: 'Informe a validade do item.',
        minShelfLifeDays: minDays,
      );
    }
    final expiryDay = _dateOnly(expiry);
    if (expiryDay.isBefore(today)) {
      return ItemValidation(
        error: 'A validade informada já passou.',
        minShelfLifeDays: minDays,
      );
    }
    if (expiryDay.isBefore(reference)) {
      return ItemValidation(
        error: 'O item vence antes da data prevista de entrega.',
        minShelfLifeDays: minDays,
      );
    }
    days = expiryDay.difference(reference).inDays;
    if (days < minDays) subjectToReview = true; // RN-D03: não bloqueia
  }

  // RN-D05: oferta acima do restante entra como excedente sujeito a avaliação.
  if (need != null && item.quantity > need.remainingQty) {
    subjectToReview = true;
  }

  return ItemValidation(
    subjectToReview: subjectToReview,
    daysToExpiry: days,
    minShelfLifeDays: minDays,
  );
}

/// Validação completa antes de confirmar (passos 1–4). Retorna a lista de
/// problemas que impedem o envio; vazia quando a doação pode ser confirmada.
List<String> validateDonationDraft({
  required List<DonationItem> items,
  required DonationRules rules,
  required Map<String, DonationNeed> needsById,
  required DonationPoint? point,
  required DateTime? windowFrom,
  required DateTime? windowTo,
  required bool termsAccepted,
  required int openDonationsCount,
  DateTime? now,
}) {
  final errors = <String>[];
  final clock = now ?? DateTime.now();

  if (items.isEmpty) errors.add('Adicione pelo menos um item.');
  if (items.length > rules.maxItems) {
    errors.add('Máximo de ${rules.maxItems} itens por doação.');
  }
  if (openDonationsCount >= rules.maxOpenPledges) {
    errors.add(
      'Você já tem $openDonationsCount doações em andamento. '
      'Aguarde a triagem para registrar outra.',
    );
  }

  if (point == null) {
    errors.add('Escolha o ponto de entrega.');
  } else if (windowFrom == null || windowTo == null) {
    errors.add('Escolha o dia e o horário da entrega.');
  } else {
    if (!windowTo.isAfter(windowFrom)) {
      errors.add('O horário final deve ser depois do horário inicial.');
    }
    if (windowFrom.isBefore(clock)) {
      errors.add('A janela de entrega precisa ser no futuro.');
    }
    if (!point.acceptsWindow(windowFrom, windowTo)) {
      errors.add('A janela está fora do horário do ponto (${point.hoursSummary}).');
    }
  }

  for (final item in items) {
    final result = validateDonationItem(
      item,
      rules: rules,
      need: item.needId == null ? null : needsById[item.needId],
      referenceDate: windowFrom,
      now: clock,
    );
    if (!result.isValid) errors.add('${item.description}: ${result.error}');
  }

  if (!termsAccepted) errors.add('Aceite os termos para confirmar a doação.');
  return errors;
}
