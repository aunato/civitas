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
  }) async {
    final user = UserEntity(
      uid: 'mock_uid_new',
      email: email,
      rol: rol,
      reputacion: 100,
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

  void dispose() {
    _controller.close();
  }
}
