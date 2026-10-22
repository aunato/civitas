class UserEntity {
  final String uid;
  final String email;
  final String rol; // 'vecino', 'dirigente', 'institucional'
  final int reputacion; // 0 a 100
  final String? nombre;
  final String? rut;
  final String? ciudad;
  final String? telefono;
  final String? direccion;
  final String? juntaVecinal;
  final String? fcmToken;
  final double? latitude;
  final double? longitude;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.rol,
    required this.reputacion,
    this.nombre,
    this.rut,
    this.ciudad,
    this.telefono,
    this.direccion,
    this.juntaVecinal,
    this.fcmToken,
    this.latitude,
    this.longitude,
  });

  /// Regla de negocio de la tesis: Si la reputación baja de 30, la cuenta se bloquea automáticamente.
  bool get isBlocked => reputacion < 30;

  bool get isDirigente => rol.toLowerCase() == 'dirigente';
  bool get isInstitucional =>
      rol.toLowerCase() == 'institucional' ||
      rol.toLowerCase() == 'carabineros' ||
      rol.toLowerCase() == 'pdi';
  bool get isAdmin => rol.toLowerCase() == 'administrador';
  bool get isVecino => !isDirigente && !isInstitucional && !isAdmin;

  UserEntity copyWith({
    String? uid,
    String? email,
    String? rol,
    int? reputacion,
    String? nombre,
    String? rut,
    String? ciudad,
    String? telefono,
    String? direccion,
    String? juntaVecinal,
    String? fcmToken,
    double? latitude,
    double? longitude,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      reputacion: reputacion ?? this.reputacion,
      nombre: nombre ?? this.nombre,
      rut: rut ?? this.rut,
      ciudad: ciudad ?? this.ciudad,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      juntaVecinal: juntaVecinal ?? this.juntaVecinal,
      fcmToken: fcmToken ?? this.fcmToken,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
