import '../entities/emergency_audio_evidence.dart';
import '../entities/anti_coercion_event.dart';

abstract class EmergencyRepository {
  /// Inicia la grabación silenciosa de audio ambiental en segundo plano (hasta 5 minutos)
  Future<EmergencyAudioEvidence> startStealthRecording({
    required String autorUid,
    required String reportId,
    required double lat,
    required double lng,
  });

  /// Detiene la grabación silenciosa actual y finaliza la evidencia
  Future<EmergencyAudioEvidence?> stopStealthRecording();

  /// Indica si la grabación de audio se encuentra activa
  bool get isRecording;

  /// Stream de duración transcurrida en segundos (0 a 300)
  Stream<int> get recordingDurationStream;

  /// Stream de la evidencia de audio en curso
  Stream<EmergencyAudioEvidence?> get currentEvidenceStream;

  /// Envía señal de coacción silenciosa a Firestore y autoridades ante código de botones de volumen
  Future<void> sendDuressSignal({
    required String autorUid,
    required double lat,
    required double lng,
    String? activeReportId,
  });

  /// Registra el evento de hardware anti-coacción
  Future<void> logAntiCoercionEvent(AntiCoercionEvent event);
}
