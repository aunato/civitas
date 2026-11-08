import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import '../repositories/network_repository.dart';

class RespondTrustRequestUseCase {
  final NetworkRepository repository;

  RespondTrustRequestUseCase(this.repository);

  Future<void> call({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  }) {
    return repository.respondTrustRequest(
      requestId: requestId,
      accept: accept,
      respondingUser: respondingUser,
    );
  }
}
