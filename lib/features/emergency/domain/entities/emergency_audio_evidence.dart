/// Entidad de dominio que representa la evidencia de audio ambiental
/// capturada de forma sigilosa ante la activación de un Pánico SOS (Tesis CIVITAS).
class EmergencyAudioEvidence {
  final String id;
  final String autorUid;
  final String emergencyReportId;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds; // Máximo 300 segundos (5 minutos)
  final String filePath;
  final bool isCompleted;
  final double latitude;
  final double longitude;
  final String? secureEvidenceUrl;

  const EmergencyAudioEvidence({
    required this.id,
    required this.autorUid,
    required this.emergencyReportId,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.filePath,
    required this.isCompleted,
    required this.latitude,
    required this.longitude,
    this.secureEvidenceUrl,
  });

  /// Duración máxima permitida por requerimiento de seguridad: 5 minutos (300 segundos)
  static const int maxDurationLimitSeconds = 300;

  bool get reachedMaxDuration => durationSeconds >= maxDurationLimitSeconds;

  /// Genera mensaje formateado con geolocalización y aviso de evidencia para Red de Confianza / WhatsApp
  String generateWhatsAppEmergencyMessage() {
    final latStr = latitude.toStringAsFixed(5);
    final lngStr = longitude.toStringAsFixed(5);
    final mapUrl = 'https://www.google.com/maps?q=$latStr,$lngStr';

    return '🚨 *ALERTA SOS CIVITAS - MODO SIGILOSO ACTIVADO*\n'
        '⚠️ El vecino ha disparado una alerta crítica de emergencia.\n'
        '📍 *Ubicación GPS:* $mapUrl\n'
        '🎙️ *Evidencia de Audio Ambiental:* Grabación de seguridad de hasta 5 min ($durationSeconds s registradas).\n'
        '🛡️ *ID de Alerta:* $emergencyReportId\n'
        '🇨🇱 *CIVITAS - Red de Seguridad Ciudadana y Alerta Temprana*';
  }

  /// Enlace universal para compartir de inmediato por WhatsApp
  String get whatsappShareUrl {
    final text = Uri.encodeComponent(generateWhatsAppEmergencyMessage());
    return 'https://wa.me/?text=$text';
  }

  EmergencyAudioEvidence copyWith({
    String? id,
    String? autorUid,
    String? emergencyReportId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? filePath,
    bool? isCompleted,
    double? latitude,
    double? longitude,
    String? secureEvidenceUrl,
  }) {
    return EmergencyAudioEvidence(
      id: id ?? this.id,
      autorUid: autorUid ?? this.autorUid,
      emergencyReportId: emergencyReportId ?? this.emergencyReportId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      filePath: filePath ?? this.filePath,
      isCompleted: isCompleted ?? this.isCompleted,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      secureEvidenceUrl: secureEvidenceUrl ?? this.secureEvidenceUrl,
    );
  }
}
