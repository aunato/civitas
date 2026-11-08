import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/trusted_contact_entity.dart';

class TrustedContactModel extends TrustedContactEntity {
  const TrustedContactModel({
    required super.id,
    required super.name,
    required super.phone,
    super.email,
    super.civitasUid,
    super.isVerified = false,
    super.relationship = 'Vecino de Confianza',
    required super.addedAt,
  });

  factory TrustedContactModel.fromEntity(TrustedContactEntity entity) {
    return TrustedContactModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      email: entity.email,
      civitasUid: entity.civitasUid,
      isVerified: entity.isVerified,
      relationship: entity.relationship,
      addedAt: entity.addedAt,
    );
  }

  factory TrustedContactModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrustedContactModel.fromMap(data, id: doc.id);
  }

  factory TrustedContactModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parsedAddedAt = DateTime.now();
    if (map['added_at'] is Timestamp) {
      parsedAddedAt = (map['added_at'] as Timestamp).toDate();
    } else if (map['added_at'] is String) {
      parsedAddedAt = DateTime.tryParse(map['added_at'] as String) ?? DateTime.now();
    }

    return TrustedContactModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? map['nombre'] ?? '',
      phone: map['phone'] ?? map['telefono'] ?? '',
      email: map['email'] ?? map['correo'],
      civitasUid: map['civitas_uid'] ?? map['uid'],
      isVerified: map['is_verified'] ?? map['verificado'] ?? false,
      relationship: map['relationship'] ?? map['parentesco'] ?? 'Vecino de Confianza',
      addedAt: parsedAddedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'civitas_uid': civitasUid,
      'is_verified': isVerified,
      'relationship': relationship,
      'added_at': Timestamp.fromDate(addedAt),
    };
  }
}
