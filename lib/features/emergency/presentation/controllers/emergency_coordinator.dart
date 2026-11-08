import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/emergency_audio_evidence.dart';
import '../../domain/usecases/stealth_sos_usecases.dart';
import '../../data/services/stealth_audio_recorder_service.dart';
import '../../data/services/hardware_button_listener_service.dart';
import '../../data/repositories/emergency_repository_impl.dart';

/// Coordinador central de eventos de emergencia, grabación sigilosa de audio y protocolo anti-coacción.
class EmergencyCoordinator {
  static final EmergencyCoordinator _instance =
      EmergencyCoordinator._internal();

  factory EmergencyCoordinator() => _instance;

  EmergencyCoordinator._internal() {
    _initServices();
  }

  late final StealthAudioRecorderService _audioService;
  late final HardwareButtonListenerService _hardwareService;
  late final EmergencyRepositoryImpl _emergencyRepository;

  late final TriggerStealthRecordingUseCase _triggerStealthRecordingUseCase;
  late final StopStealthRecordingUseCase _stopStealthRecordingUseCase;
  late final HandleAntiCoercionTriggerUseCase _handleAntiCoercionTriggerUseCase;

  String? _activeReportId;
  String? _currentUserUid;
  double _currentLat = -20.2167;
  double _currentLng = -70.1417;

  VoidCallback? onCoercionTriggeredCallback;

  void _initServices() {
    _audioService = StealthAudioRecorderService();
    _hardwareService = HardwareButtonListenerService();
    _emergencyRepository = EmergencyRepositoryImpl(
      audioRecorderService: _audioService,
    );

    _triggerStealthRecordingUseCase =
        TriggerStealthRecordingUseCase(_emergencyRepository);
    _stopStealthRecordingUseCase =
        StopStealthRecordingUseCase(_emergencyRepository);
    _handleAntiCoercionTriggerUseCase =
        HandleAntiCoercionTriggerUseCase(_emergencyRepository);
  }

  /// Inicializa la escucha de botones físicos para el usuario actual
  void initialize({
    required String userUid,
    double defaultLat = -20.2167,
    double defaultLng = -70.1417,
    VoidCallback? onCoercion,
  }) {
    _currentUserUid = userUid;
    _currentLat = defaultLat;
    _currentLng = defaultLng;
    onCoercionTriggeredCallback = onCoercion;

    _hardwareService.startListening(
      onCoercionTriggered: _onHardwareCoercionDetected,
    );
  }

  void updateLocation(double lat, double lng) {
    _currentLat = lat;
    _currentLng = lng;
  }

  /// Se ejecuta al presionar el Botón de Pánico SOS
  Future<EmergencyAudioEvidence> handleSosTriggered({
    required String reportId,
    required String autorUid,
    required double lat,
    required double lng,
  }) async {
    _activeReportId = reportId;
    _currentUserUid = autorUid;
    _currentLat = lat;
    _currentLng = lng;

    return await _triggerStealthRecordingUseCase.call(
      autorUid: autorUid,
      reportId: reportId,
      lat: lat,
      lng: lng,
    );
  }

  /// Se ejecuta cuando se detectan las 3 pulsaciones de volumen abajo
  Future<void> _onHardwareCoercionDetected() async {
    final uid = _currentUserUid ?? 'vecino_anonimo';
    final wasActive = _activeReportId != null;

    debugPrint(
      '[EmergencyCoordinator] ⚡ Procesando evento anti-coacción (SOS Activo: $wasActive)',
    );

    await _handleAntiCoercionTriggerUseCase.call(
      autorUid: uid,
      lat: _currentLat,
      lng: _currentLng,
      activeReportId: _activeReportId,
      isSosCurrentlyActive: wasActive,
    );

    // Si había una alerta activa, aparentar cancelación visual
    if (wasActive) {
      _activeReportId = null;
      await _stopStealthRecordingUseCase.call();
    } else {
      // Si no había SOS, iniciar grabación sigilosa de audio inmediata
      _activeReportId = 'sos_duress_${DateTime.now().millisecondsSinceEpoch}';
      await _triggerStealthRecordingUseCase.call(
        autorUid: uid,
        reportId: _activeReportId!,
        lat: _currentLat,
        lng: _currentLng,
      );
    }

    onCoercionTriggeredCallback?.call();
  }

  /// Detener grabación de audio
  Future<EmergencyAudioEvidence?> stopRecording() async {
    _activeReportId = null;
    return await _stopStealthRecordingUseCase.call();
  }

  bool get isRecording => _audioService.isRecording;
  Stream<int> get recordingDurationStream => _audioService.recordingDurationStream;
  Stream<EmergencyAudioEvidence?> get currentEvidenceStream =>
      _audioService.currentEvidenceStream;
  EmergencyAudioEvidence? get currentEvidence => _audioService.currentEvidence;

  void dispose() {
    _hardwareService.stopListening();
    stopRecording();
  }
}
