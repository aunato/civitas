/// Tipo de acción resultante ante el patrón de botones físicos anti-coacción.
enum AntiCoercionAction {
  /// Cancelación bajo coacción: Aparenta desactivar la alarma ante el asaltante,
  /// pero envía de forma oculta una alerta de coacción con alta prioridad a Carabineros.
  cancelAlarmUnderCoercion,

  /// Disparo sigiloso en modo coacción (Silent Duress Mode): Activa SOS sin emitir sonidos ni vibración.
  triggerSilentDuressMode,
}

/// Entidad que representa la activación del protocolo de hardware anti-coacción.
class AntiCoercionEvent {
  final String id;
  final AntiCoercionAction action;
  final DateTime timestamp;
  final int sequencePressCount;
  final double? latitude;
  final double? longitude;
  final String? originalReportId;

  const AntiCoercionEvent({
    required this.id,
    required this.action,
    required this.timestamp,
    required this.sequencePressCount,
    this.latitude,
    this.longitude,
    this.originalReportId,
  });

  /// Identificador de tipo de reporte especial para Firestore y Cloud Functions
  String get tipoReporte => 'coaccion_silenciosa';
}
