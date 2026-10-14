import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream de estado de autenticación (Soporte de sesión persistente)
  Stream<UserEntity?> get authStateChanges;

  /// Iniciar sesión con email y contraseña
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registrar nuevo vecino
  Future<UserEntity> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String rol,
  });

  /// Obtener usuario actualmente autenticado
  Future<UserEntity?> getCurrentUser();

  /// Cerrar sesión
  Future<void> signOut();

  /// Actualizar FCM token del usuario en Firestore
  Future<void> updateFcmToken(String uid, String token);
}
