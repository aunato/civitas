import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/core/services/remote_command_handler.dart';
import 'package:civitas/features/emergency/domain/entities/emergency_audio_evidence.dart';
import 'package:civitas/features/emergency/data/services/stealth_audio_recorder_service.dart';
import 'package:civitas/features/emergency/data/services/hardware_button_listener_service.dart';
import 'package:civitas/features/emergency/presentation/controllers/emergency_coordinator.dart';

void main() {
  group('Funcionalidades de Seguridad Avanzada (Audio Sigiloso & Anti-Coacción)', () {
    late StealthAudioRecorderService audioService;
    late HardwareButtonListenerService hardwareService;
    late EmergencyCoordinator coordinator;

    setUp(() {
      audioService = StealthAudioRecorderService();
      hardwareService = HardwareButtonListenerService();
      coordinator = EmergencyCoordinator();
    });

    tearDown(() {
      audioService.stopStealthRecording();
      hardwareService.stopListening();
    });

    test('1. StealthAudioRecorderService: Inicia grabación silenciosa y genera enlace de WhatsApp', () async {
      final evidence = await audioService.startStealthRecording(
        autorUid: 'vecino_test_01',
        reportId: 'sos_test_01',
        lat: -20.2167,
        lng: -70.1417,
      );

      expect(audioService.isRecording, isTrue);
      expect(evidence.autorUid, 'vecino_test_01');
      expect(evidence.emergencyReportId, 'sos_test_01');
      expect(evidence.filePath.endsWith('.m4a'), isTrue);

      // Simular transcurso de 45 segundos
      audioService.simulateTick(45);
      expect(audioService.currentSeconds, 45);

      final updatedEvidence = audioService.currentEvidence;
      expect(updatedEvidence?.durationSeconds, 45);

      // Verificar formato de mensaje para WhatsApp / Red de Confianza
      final whatsappUrl = updatedEvidence!.whatsappShareUrl;
      expect(whatsappUrl.startsWith('https://wa.me/?text='), isTrue);
      expect(whatsappUrl.contains(Uri.encodeComponent('-20.21670')), isTrue);
      expect(whatsappUrl.contains(Uri.encodeComponent('MODO SIGILOSO')), isTrue);

      // Finalizar grabación
      final finished = await audioService.stopStealthRecording();
      expect(audioService.isRecording, isFalse);
      expect(finished?.isCompleted, isTrue);
      expect(finished?.durationSeconds, 45);
    });

    test('2. StealthAudioRecorderService: Respeta límite máximo de 5 minutos (300 segundos)', () async {
      await audioService.startStealthRecording(
        autorUid: 'vecino_test_02',
        reportId: 'sos_test_02',
        lat: -20.2167,
        lng: -70.1417,
      );

      expect(audioService.isRecording, isTrue);

      // Simular que transcurren los 300 segundos (5 min)
      audioService.simulateTick(300);

      // Debe haberse detenido automáticamente al alcanzar el tope
      expect(audioService.isRecording, isFalse);
      expect(audioService.currentSeconds, 300);
      expect(audioService.currentEvidence?.reachedMaxDuration, isTrue);
    });

    test('3. HardwareButtonListenerService: 3 pulsaciones de volumen abajo activan anti-coacción', () async {
      bool coercionTriggered = false;

      hardwareService.startListening(
        onCoercionTriggered: () {
          coercionTriggered = true;
        },
      );

      // Menos de 3 pulsaciones no activan
      hardwareService.registerVolumeDownPress();
      hardwareService.registerVolumeDownPress();
      expect(coercionTriggered, isFalse);

      // La tercera pulsación dentro de la ventana de tiempo dispara el protocolo
      hardwareService.registerVolumeDownPress();
      expect(coercionTriggered, isTrue);
    });

    test('4. RemoteCommandHandler: Maneja CMD_FORCE_GPS y CMD_START_AUDIO_STREAM correctamente', () async {
      // Probar comando remoto de triangulación GPS
      final gpsHandled = await RemoteCommandHandler.handleRemoteCommand({
        'command': 'CMD_FORCE_GPS',
        'targetUid': 'vecino_remoto_01',
      });
      expect(gpsHandled, isTrue);

      // Probar comando remoto de inicio de streaming/grabación de audio
      final audioHandled = await RemoteCommandHandler.handleRemoteCommand({
        'command': 'CMD_START_AUDIO_STREAM',
        'targetUid': 'vecino_remoto_01',
      });
      expect(audioHandled, isTrue);
      expect(audioService.isRecording, isTrue);

      await audioService.stopStealthRecording();
    });

    test('5. EmergencyCoordinator: Flujo integrado de Pánico SOS con audio y anti-coacción', () async {
      coordinator.initialize(
        userUid: 'vecino_coord_01',
        defaultLat: -20.2167,
        defaultLng: -70.1417,
      );

      // Presionar Pánico SOS
      final evidence = await coordinator.handleSosTriggered(
        reportId: 'sos_coord_99',
        autorUid: 'vecino_coord_01',
        lat: -20.2167,
        lng: -70.1417,
      );

      expect(evidence.emergencyReportId, 'sos_coord_99');
      expect(coordinator.isRecording, isTrue);

      // Detener
      await coordinator.stopRecording();
      expect(coordinator.isRecording, isFalse);
    });
  });
}
