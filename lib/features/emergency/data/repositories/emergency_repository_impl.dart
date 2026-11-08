import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../domain/entities/emergency_audio_evidence.dart';
import '../../domain/entities/anti_coercion_event.dart';
import '../../domain/repositories/emergency_repository.dart';
import '../models/emergency_audio_evidence_model.dart';
import '../services/stealth_audio_recorder_service.dart';

class EmergencyRepositoryImpl implements EmergencyRepository {
  final StealthAudioRecorderService audioRecorderService;
  final FirebaseFirestore? firestore;

  EmergencyRepositoryImpl({
    StealthAudioRecorderService? audioRecorderService,
    this.firestore,
  }) : audioRecorderService =
            audioRecorderService ?? StealthAudioRecorderService();

  FirebaseFirestore get _firestore =>
      firestore ?? FirebaseFirestore.instance;

  @override
  bool get isRecording => audioRecorderService.isRecording;

  @override
  Stream<int> get recordingDurationStream =>
      audioRecorderService.recordingDurationStream;

  @override
  Stream<EmergencyAudioEvidence?> get currentEvidenceStream =>
      audioRecorderService.currentEvidenceStream;

  @override
  Future<EmergencyAudioEvidence> startStealthRecording({
    required String autorUid,
    required String reportId,
    required double lat,
    required double lng,
  }) async {
    final evidence = await audioRecorderService.startStealthRecording(
      autorUid: autorUid,
      reportId: reportId,
      lat: lat,
      lng: lng,
    );

    // Registro inicial en Firestore (asíncrono con tolerancia offline)
    if (Firebase.apps.isNotEmpty) {
      try {
        final model = EmergencyAudioEvidenceModel(
          id: evidence.id,
          autorUid: evidence.autorUid,
          emergencyReportId: evidence.emergencyReportId,
          startTime: evidence.startTime,
          durationSeconds: evidence.durationSeconds,
          filePath: evidence.filePath,
          isCompleted: false,
          latitude: evidence.latitude,
          longitude: evidence.longitude,
        );

        await _firestore
            .collection('evidencias_emergencia')
            .doc(evidence.id)
            .set(model.toFirestore())
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[EmergencyRepo] Advertencia registrando inicio de audio en Firestore: $e');
      }
    }

    return evidence;
  }

  @override
  Future<EmergencyAudioEvidence?> stopStealthRecording() async {
    final finished = await audioRecorderService.stopStealthRecording();
    if (finished != null && Firebase.apps.isNotEmpty) {
      try {
        await _firestore
            .collection('evidencias_emergencia')
            .doc(finished.id)
            .set({
          'fin_en': finished.endTime != null
              ? Timestamp.fromDate(finished.endTime!)
              : FieldValue.serverTimestamp(),
          'duracion_segundos': finished.durationSeconds,
          'completada': true,
          'actualizado_en': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[EmergencyRepo] Advertencia finalizando audio en Firestore: $e');
      }
    }
    return finished;
  }

  @override
  Future<void> sendDuressSignal({
    required String autorUid,
    required double lat,
    required double lng,
    String? activeReportId,
  }) async {
    debugPrint(
      '[EmergencyRepo] 🚨 DESPACHANDO SEÑAL DE COACCIÓN SILENCIOSA A CENTRAL POLICIAL (lat: $lat, lng: $lng)',
    );

    if (Firebase.apps.isNotEmpty) {
      try {
        final duressDocId =
            'coaccion_${DateTime.now().millisecondsSinceEpoch}';
        await _firestore.collection('reportes').doc(duressDocId).set({
          'id': duressDocId,
          'tipo': 'coaccion_silenciosa',
          'autor_uid': autorUid,
          'latitud': lat,
          'longitud': lng,
          'estado': 'ACTIVO',
          'duress_mode': true,
          'prioridad': 'MAXIMA',
          'cancelado_aparente': activeReportId != null,
          'reporte_original_id': activeReportId,
          'creado_en': FieldValue.serverTimestamp(),
          'descripcion':
              '⚠️ ALERTA DE COACCIÓN SILENCIOSA: El vecino canceló la alarma bajo amenaza o activó código de auxilio con botones físicos.',
        }).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[EmergencyRepo] Advertencia despachando duress signal: $e');
      }
    }
  }

  @override
  Future<void> logAntiCoercionEvent(AntiCoercionEvent event) async {
    debugPrint(
      '[EmergencyRepo] Evento anti-coacción registrado localmente: ${event.action} - ${event.timestamp}',
    );
  }
}
