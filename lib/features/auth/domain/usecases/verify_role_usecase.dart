import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para el flujo de aprobación/verificación de roles policiales e institucionales (Carabineros / PDI).
class VerifyRoleUseCase {
  final AuthRepository repository;

  VerifyRoleUseCase(this.repository);

  /// Aprueba o rechaza la credencial de un funcionario institucional
  Future<void> updateStatus({
    required String uid,
    required String status, // 'VERIFICADO' o 'RECHAZADO'
  }) {
    return repository.updateVerificationStatus(uid, status);
  }

  /// Lista funcionarios pendientes de validación
  Future<List<UserEntity>> getPendingOfficers() {
    return repository.getPendingVerificationUsers();
  }
}
