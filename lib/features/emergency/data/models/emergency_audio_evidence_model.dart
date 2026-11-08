import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/emergency_audio_evidence.dart';

class EmergencyAudioEvidenceModel extends EmergencyAudioEvidence {
  const EmergencyAudioEvidenceModel({
    required super.id,
    required super.autorUid,
    required super.emergencyReportId,
    required super.startTime,
    super.endTime,
    required super.durationSeconds,
    required super.filePath,
    required super.isCompleted,
    required super.latitude,
    required super.longitude,
    super.secureEvidenceUrl,
  });

  factory EmergencyAudioEvidenceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime start = DateTime.now();
    if (data['inicio_en'] is Timestamp) {
      start = (data['inicio_en'] as Timestamp).toDate();
    }

    DateTime? end;
    if (data['fin_en'] is Timestamp) {
      end = (data['fin_en'] as Timestamp).toDate();
    }

    return EmergencyAudioEvidenceModel(
      id: doc.id,
      autorUid: data['autor_uid'] as String? ?? '',
      emergencyReportId: data['reporte_id'] as String? ?? '',
      startTime: start,
      endTime: end,
      durationSeconds: (data['duracion_segundos'] as num?)?.toInt() ?? 0,
      filePath: data['archivo_ruta'] as String? ?? '',
      isCompleted: data['completada'] as bool? ?? false,
      latitude: (data['latitud'] as num?)?.toDouble() ?? -20.2167,
      longitude: (data['longitud'] as num?)?.toDouble() ?? -70.1417,
      secureEvidenceUrl: data['evidencia_url'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'autor_uid': autorUid,
      'reporte_id': emergencyReportId,
      'inicio_en': Timestamp.fromDate(startTime),
      'fin_en': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duracion_segundos': durationSeconds,
      'archivo_ruta': filePath,
      'completada': isCompleted,
      'latitud': latitude,
      'longitud': longitude,
      'evidencia_url': secureEvidenceUrl,
      'actualizado_en': FieldValue.serverTimestamp(),
    };
  }
}
