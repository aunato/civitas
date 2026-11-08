import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream de estado de autenticación (Soporte de sesión persistente)
  Stream<UserEntity?> get authStateChanges;

  /// Iniciar sesión con email y contraseña
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registrar nuevo usuario (Vecino, Dirigente o Funcionario Institucional)
  Future<UserEntity> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String rol,
    String? credencialUrl,
    String? institucion,
    String? placaInstitucional,
    String? nombre,
  });

  /// Obtener usuario actualmente autenticado
  Future<UserEntity?> getCurrentUser();

  /// Cerrar sesión
  Future<void> signOut();

  /// Actualizar FCM token del usuario en Firestore
  Future<void> updateFcmToken(String uid, String token);

  /// Actualizar estado de verificación de rol institucional ('VERIFICADO', 'PENDING_VERIFICATION', 'RECHAZADO')
  Future<void> updateVerificationStatus(String uid, String status);

  /// Obtener lista de funcionarios en estado PENDING_VERIFICATION
  Future<List<UserEntity>> getPendingVerificationUsers();
}
