class UserEntity {
  final String uid;
  final String email;
  final String rol; // 'vecino', 'dirigente', 'administrador'
  final int reputacion; // 0 a 100
  final String? fcmToken;
  final double? latitude;
  final double? longitude;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.rol,
    required this.reputacion,
    this.fcmToken,
    this.latitude,
    this.longitude,
  });

  /// Regla de negocio de la tesis: Si la reputación baja de 30, la cuenta se bloquea automáticamente.
  bool get isBlocked => reputacion < 30;

  bool get isDirigente => rol == 'dirigente' || rol == 'administrador';
  bool get isAdmin => rol == 'administrador';
}
