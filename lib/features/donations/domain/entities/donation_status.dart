/// Estados da doação (máquina de estados da Sprint 2, seção 4.4).
///
/// O valor gravado no Firestore (`value`) é o do relatório: `recebida_parcial`
/// usa underscore, enquanto o identificador Dart é camelCase.
enum DonationStatus {
  pendente('pendente', 'Pendente'),
  aprovada('aprovada', 'Aprovada'),
  recebida('recebida', 'Recebida'),
  recebidaParcial('recebida_parcial', 'Recebida parcialmente'),
  recusada('recusada', 'Recusada'),
  cancelada('cancelada', 'Cancelada'),
  expirada('expirada', 'Expirada');

  const DonationStatus(this.value, this.label);

  final String value;
  final String label;

  /// Tolerante a valores desconhecidos (RNF21): cai em `pendente`.
  static DonationStatus fromValue(String? raw) {
    return DonationStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => DonationStatus.pendente,
    );
  }

  bool get isTerminal => switch (this) {
        DonationStatus.pendente || DonationStatus.aprovada => false,
        _ => true,
      };

  /// Em andamento = ainda reserva quantidade (pendente ou aprovada).
  bool get isOpen => !isTerminal;

  bool get isConcluded =>
      this == DonationStatus.recebida || this == DonationStatus.recebidaParcial;

  bool get isClosedWithoutDelivery =>
      this == DonationStatus.recusada ||
      this == DonationStatus.cancelada ||
      this == DonationStatus.expirada;

  /// Transições permitidas (tabela 13 do relatório da Sprint 2).
  static const Map<DonationStatus, Set<DonationStatus>> allowedTransitions = {
    DonationStatus.pendente: {
      DonationStatus.aprovada,
      DonationStatus.recusada,
      DonationStatus.cancelada,
      DonationStatus.expirada,
    },
    DonationStatus.aprovada: {
      DonationStatus.recebida,
      DonationStatus.recebidaParcial,
      DonationStatus.cancelada,
      DonationStatus.expirada,
    },
  };

  bool canTransitionTo(DonationStatus next) =>
      (allowedTransitions[this] ?? const <DonationStatus>{}).contains(next);

  /// O doador só pode cancelar, e apenas enquanto a doação está aberta.
  bool get donorCanCancel => isOpen;
}
