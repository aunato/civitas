import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<UserEntity> call({
    required String email,
    required String password,
    String rol = 'VECINO',
    String? credencialUrl,
    String? institucion,
    String? placaInstitucional,
    String? nombre,
  }) {
    return repository.registerWithEmailAndPassword(
      email: email.trim(),
      password: password,
      rol: rol,
      credencialUrl: credencialUrl,
      institucion: institucion,
      placaInstitucional: placaInstitucional,
      nombre: nombre,
    );
  }
}
