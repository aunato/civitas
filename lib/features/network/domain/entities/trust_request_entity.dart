/// Entidad de dominio que modela una solicitud de confianza vecinal con credencial CIVITAS.
class TrustRequestEntity {
  final String id;
  final String fromUid;
  final String fromName;
  final String fromPhone;
  final String? fromRut;
  final String fromRol;
  final int fromReputacion;
  final String fromCredencialFolio;
  final String toPhone;
  final String? toUid;
  final String status; // 'PENDING', 'ACCEPTED', 'REJECTED'
  final DateTime createdAt;
  final DateTime? respondedAt;

  const TrustRequestEntity({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromPhone,
    this.fromRut,
    required this.fromRol,
    required this.fromReputacion,
    required this.fromCredencialFolio,
    required this.toPhone,
    this.toUid,
    this.status = 'PENDING',
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  TrustRequestEntity copyWith({
    String? id,
    String? fromUid,
    String? fromName,
    String? fromPhone,
    String? fromRut,
    String? fromRol,
    int? fromReputacion,
    String? fromCredencialFolio,
    String? toPhone,
    String? toUid,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return TrustRequestEntity(
      id: id ?? this.id,
      fromUid: fromUid ?? this.fromUid,
      fromName: fromName ?? this.fromName,
      fromPhone: fromPhone ?? this.fromPhone,
      fromRut: fromRut ?? this.fromRut,
      fromRol: fromRol ?? this.fromRol,
      fromReputacion: fromReputacion ?? this.fromReputacion,
      fromCredencialFolio: fromCredencialFolio ?? this.fromCredencialFolio,
      toPhone: toPhone ?? this.toPhone,
      toUid: toUid ?? this.toUid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}
