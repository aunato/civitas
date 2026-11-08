import '../entities/emergency_audio_evidence.dart';
import '../entities/anti_coercion_event.dart';
import '../repositories/emergency_repository.dart';

/// Inicia la grabación sigilosa de audio (hasta 5 minutos) vinculada al botón de pánico SOS
class TriggerStealthRecordingUseCase {
  final EmergencyRepository repository;

  TriggerStealthRecordingUseCase(this.repository);

  Future<EmergencyAudioEvidence> call({
    required String autorUid,
    required String reportId,
    required double lat,
    required double lng,
  }) {
    return repository.startStealthRecording(
      autorUid: autorUid,
      reportId: reportId,
      lat: lat,
      lng: lng,
    );
  }
}

/// Detiene la grabación sigilosa de audio
class StopStealthRecordingUseCase {
  final EmergencyRepository repository;

  StopStealthRecordingUseCase(this.repository);

  Future<EmergencyAudioEvidence?> call() {
    return repository.stopStealthRecording();
  }
}

/// Procesa la cancelación o activación bajo coacción activada por botones físicos (3 pulsaciones de volumen abajo)
class HandleAntiCoercionTriggerUseCase {
  final EmergencyRepository repository;

  HandleAntiCoercionTriggerUseCase(this.repository);

  Future<void> call({
    required String autorUid,
    required double lat,
    required double lng,
    String? activeReportId,
    required bool isSosCurrentlyActive,
  }) async {
    final event = AntiCoercionEvent(
      id: 'anticoercion_${DateTime.now().millisecondsSinceEpoch}',
      action: isSosCurrentlyActive
          ? AntiCoercionAction.cancelAlarmUnderCoercion
          : AntiCoercionAction.triggerSilentDuressMode,
      timestamp: DateTime.now(),
      sequencePressCount: 3,
      latitude: lat,
      longitude: lng,
      originalReportId: activeReportId,
    );

    // 1. Registrar evento local / analítico
    await repository.logAntiCoercionEvent(event);

    // 2. Despachar señal prioritaria a la nube
    await repository.sendDuressSignal(
      autorUid: autorUid,
      lat: lat,
      lng: lng,
      activeReportId: activeReportId,
    );
  }
}
