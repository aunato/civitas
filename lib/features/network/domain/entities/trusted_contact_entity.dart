/// Entidad de dominio que representa a un contacto en la Red de Confianza vecinal (Tesis CIVITAS).
class TrustedContactEntity {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? civitasUid;
  final bool isVerified;
  final bool isRegisteredInCivitas; // Indica si el contacto ya está registrado en la base de usuarios CIVITAS
  final String relationship; // 'Familiar', 'Vecino de Confianza', 'Comité de Seguridad'
  final DateTime addedAt;

  const TrustedContactEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.civitasUid,
    this.isVerified = false,
    this.isRegisteredInCivitas = false,
    this.relationship = 'Vecino de Confianza',
    required this.addedAt,
  });

  TrustedContactEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? civitasUid,
    bool? isVerified,
    bool? isRegisteredInCivitas,
    String? relationship,
    DateTime? addedAt,
  }) {
    return TrustedContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      civitasUid: civitasUid ?? this.civitasUid,
      isVerified: isVerified ?? this.isVerified,
      isRegisteredInCivitas: isRegisteredInCivitas ?? this.isRegisteredInCivitas,
      relationship: relationship ?? this.relationship,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
