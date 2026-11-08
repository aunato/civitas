import 'dart:async';
import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/auth/domain/repositories/auth_repository.dart';
import 'package:civitas/core/errors/exceptions.dart';

class MockAuthRepository implements AuthRepository {
  final StreamController<UserEntity?> _controller = StreamController<UserEntity?>.broadcast();
  UserEntity? _currentUser;
  bool shouldFail = false;

  @override
  Stream<UserEntity?> get authStateChanges => _controller.stream;

  void emitAuthState(UserEntity? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (shouldFail) {
      throw AuthException('Credenciales incorrectas o usuario no encontrado.');
    }

    final user = UserEntity(
      uid: 'mock_uid_123',
      email: email,
      rol: 'vecino',
      reputacion: 100,
    );

    emitAuthState(user);
    return user;
  }

  @override
  Future<UserEntity> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String rol,
    String? credencialUrl,
    String? institucion,
    String? placaInstitucional,
    String? nombre,
  }) async {
    final isInst = rol.toLowerCase() == 'institucional' ||
        rol.toLowerCase() == 'carabineros' ||
        rol.toLowerCase() == 'pdi';

    final user = UserEntity(
      uid: 'mock_uid_new',
      email: email,
      rol: rol,
      reputacion: 100,
      nombre: nombre,
      estadoVerificacion: isInst ? 'PENDING_VERIFICATION' : 'VERIFICADO',
      credencialUrl: credencialUrl,
      institucion: institucion,
      placaInstitucional: placaInstitucional,
    );
    emitAuthState(user);
    return user;
  }

  @override
  Future<UserEntity?> getCurrentUser() async => _currentUser;

  @override
  Future<void> signOut() async {
    emitAuthState(null);
  }

  @override
  Future<void> updateFcmToken(String uid, String token) async {}

  @override
  Future<void> updateVerificationStatus(String uid, String status) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(estadoVerificacion: status);
      emitAuthState(_currentUser);
    }
  }

  @override
  Future<List<UserEntity>> getPendingVerificationUsers() async {
    if (_currentUser != null && _currentUser!.isPendingVerification) {
      return [_currentUser!];
    }
    return [];
  }

  void dispose() {
    _controller.close();
  }
}
