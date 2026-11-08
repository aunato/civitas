import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/emergency_audio_evidence.dart';

/// Servicio de grabación ambiental sigilosa en segundo plano para Pánico SOS (Tesis CIVITAS).
///
/// Requerimiento: Graba hasta 5 minutos (300s) de forma completamente silenciosa
/// (sin pitidos ni vibraciones de inicio que alerten a un agresor), generando
/// el contenedor seguro de evidencia forense y enlace de despacho para Red de Confianza / WhatsApp.
class StealthAudioRecorderService {
  static final StealthAudioRecorderService _instance =
      StealthAudioRecorderService._internal();

  factory StealthAudioRecorderService() => _instance;

  StealthAudioRecorderService._internal();

  Timer? _timer;
  int _currentSeconds = 0;
  bool _isRecording = false;

  EmergencyAudioEvidence? _currentEvidence;

  final StreamController<int> _durationController =
      StreamController<int>.broadcast();
  final StreamController<EmergencyAudioEvidence?> _evidenceController =
      StreamController<EmergencyAudioEvidence?>.broadcast();

  bool get isRecording => _isRecording;
  int get currentSeconds => _currentSeconds;
  EmergencyAudioEvidence? get currentEvidence => _currentEvidence;

  Stream<int> get recordingDurationStream => _durationController.stream;
  Stream<EmergencyAudioEvidence?> get currentEvidenceStream =>
      _evidenceController.stream;

  /// Inicia la grabación silenciosa de audio
  Future<EmergencyAudioEvidence> startStealthRecording({
    required String autorUid,
    required String reportId,
    required double lat,
    required double lng,
    int maxDurationLimitSeconds = EmergencyAudioEvidence.maxDurationLimitSeconds,
  }) async {
    // Si ya estuviera grabando, detenemos la anterior
    if (_isRecording) {
      await stopStealthRecording();
    }

    final startTime = DateTime.now();
    final evidenceId = 'audio_sos_${startTime.millisecondsSinceEpoch}';
    final filePath = 'civitas_sos_${startTime.millisecondsSinceEpoch}.m4a';

    _currentEvidence = EmergencyAudioEvidence(
      id: evidenceId,
      autorUid: autorUid,
      emergencyReportId: reportId,
      startTime: startTime,
      durationSeconds: 0,
      filePath: filePath,
      isCompleted: false,
      latitude: lat,
      longitude: lng,
    );

    _isRecording = true;
    _currentSeconds = 0;
    _durationController.add(0);
    _evidenceController.add(_currentEvidence);

    debugPrint(
      '[StealthAudioService] 🎙️ Grabación sigilosa iniciada en segundo plano para SOS: $reportId (Máx 5 min).',
    );

    // Temporizador de 1 segundo hasta alcanzar el límite de 300 segundos (5 minutos)
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentSeconds++;
      _durationController.add(_currentSeconds);

      if (_currentEvidence != null) {
        _currentEvidence = _currentEvidence!.copyWith(
          durationSeconds: _currentSeconds,
        );
        _evidenceController.add(_currentEvidence);
      }

      if (_currentSeconds >= maxDurationLimitSeconds) {
        debugPrint(
          '[StealthAudioService] ⏱️ Límite máximo de 5 minutos alcanzado. Finalizando evidencia automáticamente.',
        );
        stopStealthRecording();
      }
    });

    return _currentEvidence!;
  }

  /// Detiene y finaliza la evidencia de audio
  Future<EmergencyAudioEvidence?> stopStealthRecording() async {
    if (!_isRecording && _currentEvidence == null) return null;

    _timer?.cancel();
    _timer = null;
    _isRecording = false;

    if (_currentEvidence != null) {
      _currentEvidence = _currentEvidence!.copyWith(
        endTime: DateTime.now(),
        isCompleted: true,
        durationSeconds: _currentSeconds,
      );
      _evidenceController.add(_currentEvidence);
    }

    debugPrint(
      '[StealthAudioService] ⏹️ Grabación sigilosa finalizada con éxito. Duración: $_currentSeconds segundos.',
    );

    return _currentEvidence;
  }

  /// Permite simular avance de tiempo en pruebas unitarias
  @visibleForTesting
  void simulateTick(int seconds) {
    if (!_isRecording) return;
    _currentSeconds += seconds;
    _durationController.add(_currentSeconds);
    if (_currentEvidence != null) {
      _currentEvidence = _currentEvidence!.copyWith(
        durationSeconds: _currentSeconds,
      );
      _evidenceController.add(_currentEvidence);
    }
    if (_currentSeconds >= EmergencyAudioEvidence.maxDurationLimitSeconds) {
      stopStealthRecording();
    }
  }

  void dispose() {
    _timer?.cancel();
    _durationController.close();
    _evidenceController.close();
  }
}
