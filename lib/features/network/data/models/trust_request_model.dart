import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/trust_request_entity.dart';

class TrustRequestModel extends TrustRequestEntity {
  const TrustRequestModel({
    required super.id,
    required super.fromUid,
    required super.fromName,
    required super.fromPhone,
    super.fromRut,
    required super.fromRol,
    required super.fromReputacion,
    required super.fromCredencialFolio,
    required super.toPhone,
    super.toUid,
    super.status = 'PENDING',
    required super.createdAt,
    super.respondedAt,
  });

  factory TrustRequestModel.fromEntity(TrustRequestEntity entity) {
    return TrustRequestModel(
      id: entity.id,
      fromUid: entity.fromUid,
      fromName: entity.fromName,
      fromPhone: entity.fromPhone,
      fromRut: entity.fromRut,
      fromRol: entity.fromRol,
      fromReputacion: entity.fromReputacion,
      fromCredencialFolio: entity.fromCredencialFolio,
      toPhone: entity.toPhone,
      toUid: entity.toUid,
      status: entity.status,
      createdAt: entity.createdAt,
      respondedAt: entity.respondedAt,
    );
  }

  factory TrustRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrustRequestModel.fromMap(data, id: doc.id);
  }

  factory TrustRequestModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parsedCreatedAt = DateTime.now();
    if (map['created_at'] is Timestamp) {
      parsedCreatedAt = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['created_at'] as String) ?? DateTime.now();
    }

    DateTime? parsedRespondedAt;
    if (map['responded_at'] is Timestamp) {
      parsedRespondedAt = (map['responded_at'] as Timestamp).toDate();
    } else if (map['responded_at'] is String) {
      parsedRespondedAt = DateTime.tryParse(map['responded_at'] as String);
    }

    return TrustRequestModel(
      id: id ?? map['id'] ?? '',
      fromUid: map['from_uid'] ?? '',
      fromName: map['from_name'] ?? '',
      fromPhone: map['from_phone'] ?? '',
      fromRut: map['from_rut'],
      fromRol: map['from_rol'] ?? 'Vecino',
      fromReputacion: (map['from_reputacion'] is num) ? (map['from_reputacion'] as num).toInt() : 100,
      fromCredencialFolio: map['from_credencial_folio'] ?? 'CIVITAS-CL-PENDING',
      toPhone: map['to_phone'] ?? '',
      toUid: map['to_uid'],
      status: map['status'] ?? 'PENDING',
      createdAt: parsedCreatedAt,
      respondedAt: parsedRespondedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'from_uid': fromUid,
      'from_name': fromName,
      'from_phone': fromPhone,
      'from_rut': fromRut,
      'from_rol': fromRol,
      'from_reputacion': fromReputacion,
      'from_credencial_folio': fromCredencialFolio,
      'to_phone': toPhone,
      'to_uid': toUid,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'responded_at': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
