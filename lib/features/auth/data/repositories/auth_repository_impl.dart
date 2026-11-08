import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<UserEntity?> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await remoteDataSource.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
    return await remoteDataSource.registerWithEmailAndPassword(
      email: email,
      password: password,
      rol: rol,
      credencialUrl: credencialUrl,
      institucion: institucion,
      placaInstitucional: placaInstitucional,
      nombre: nombre,
    );
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await remoteDataSource.getCurrentUser();
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Future<void> updateFcmToken(String uid, String token) async {
    await remoteDataSource.updateFcmToken(uid, token);
  }

  @override
  Future<void> updateVerificationStatus(String uid, String status) async {
    await remoteDataSource.updateVerificationStatus(uid, status);
  }

  @override
  Future<List<UserEntity>> getPendingVerificationUsers() async {
    return await remoteDataSource.getPendingVerificationUsers();
  }
}
