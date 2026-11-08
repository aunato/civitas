import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso para completar el perfil del usuario durante el flujo de Onboarding inicial.
class CompleteProfileUseCase {
  final AuthRepository repository;

  CompleteProfileUseCase(this.repository);

  Future<UserEntity> call({
    required String uid,
    required String nombre,
    required String rut,
    required String telefono,
    required String ciudad,
    required String direccion,
    String? juntaVecinal,
  }) {
    return repository.completeProfile(
      uid: uid,
      nombre: nombre,
      rut: rut,
      telefono: telefono,
      ciudad: ciudad,
      direccion: direccion,
      juntaVecinal: juntaVecinal,
    );
  }
}
