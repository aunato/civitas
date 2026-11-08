import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../features/emergency/data/services/stealth_audio_recorder_service.dart';
import 'location_service.dart';

/// Manejador de comandos remotos de seguridad y antirrobo recibidos vía FCM de alta prioridad (Tesis CIVITAS).
class RemoteCommandHandler {
  static final StreamController<Map<String, dynamic>> _commandStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onCommandExecuted =>
      _commandStreamController.stream;

  /// Procesa los datos de un mensaje FCM entrante
  static Future<bool> handleRemoteCommand(Map<String, dynamic> data) async {
    final command = data['command'] ?? data['cmd'];
    final targetUid = data['targetUid'] ?? data['uid'] ?? 'usuario_desconocido';

    if (command == null) return false;

    debugPrint('[RemoteCommand] 📡 Comando remoto recibido vía FCM: $command para usuario: $targetUid');

    switch (command.toString().toUpperCase()) {
      case 'CMD_FORCE_GPS':
        await _executeForceGps(targetUid, data);
        _commandStreamController.add({
          'command': 'CMD_FORCE_GPS',
          'targetUid': targetUid,
          'status': 'SUCCESS',
          'timestamp': DateTime.now().toIso8601String(),
        });
        return true;

      case 'CMD_START_AUDIO_STREAM':
        await _executeStartAudioStream(targetUid, data);
        _commandStreamController.add({
          'command': 'CMD_START_AUDIO_STREAM',
          'targetUid': targetUid,
          'status': 'SUCCESS',
          'timestamp': DateTime.now().toIso8601String(),
        });
        return true;

      default:
        debugPrint('[RemoteCommand] Comando desconocido: $command');
        return false;
    }
  }

  /// Ejecuta CMD_FORCE_GPS: fuerza triangulación satelital y sube coordenadas a Firestore
  static Future<void> _executeForceGps(
    String targetUid,
    Map<String, dynamic> data,
  ) async {
    try {
      final locationService = LocationService();
      final coords = await locationService.getCurrentLatLng().timeout(
            const Duration(seconds: 4),
            onTimeout: () => LocationService.defaultLatLng,
          );

      debugPrint(
        '[RemoteCommand] 📍 CMD_FORCE_GPS ejecutado: (${coords.latitude}, ${coords.longitude})',
      );

      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(targetUid)
            .collection('antirrobo_tracking')
            .add({
          'comando': 'CMD_FORCE_GPS',
          'latitud': coords.latitude,
          'longitud': coords.longitude,
          'ejecutado_en': FieldValue.serverTimestamp(),
          'fuente': 'FCM_HIGH_PRIORITY_REMOTE_CMD',
        }).timeout(const Duration(seconds: 3));

        // Actualizar última ubicación en el perfil
        await FirebaseFirestore.instance.collection('usuarios').doc(targetUid).set({
          'ultima_ubicacion': GeoPoint(coords.latitude, coords.longitude),
          'latitud': coords.latitude,
          'longitud': coords.longitude,
          'actualizado_en': FieldValue.serverTimestamp(),
          'antirrobo_activo': true,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[RemoteCommand] Error ejecutando CMD_FORCE_GPS: $e');
    }
  }

  /// Ejecuta CMD_START_AUDIO_STREAM: activa sigilosamente la grabación de audio de hasta 5 minutos
  static Future<void> _executeStartAudioStream(
    String targetUid,
    Map<String, dynamic> data,
  ) async {
    try {
      final recorder = StealthAudioRecorderService();
      final reportId = 'remoto_audio_${DateTime.now().millisecondsSinceEpoch}';

      final evidence = await recorder.startStealthRecording(
        autorUid: targetUid,
        reportId: reportId,
        lat: LocationService.defaultLatLng.latitude,
        lng: LocationService.defaultLatLng.longitude,
      );

      debugPrint(
        '[RemoteCommand] 🎙️ CMD_START_AUDIO_STREAM activado exitosamente. Evidencia ID: ${evidence.id}',
      );

      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(targetUid)
            .collection('evidencias_remotas')
            .doc(evidence.id)
            .set({
          'evidencia_id': evidence.id,
          'comando': 'CMD_START_AUDIO_STREAM',
          'iniciado_en': FieldValue.serverTimestamp(),
          'archivo_ruta': evidence.filePath,
        }).timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('[RemoteCommand] Error ejecutando CMD_START_AUDIO_STREAM: $e');
    }
  }
}
