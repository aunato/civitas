import '../../auth/domain/entities/user_entity.dart';
import '../entities/trust_request_entity.dart';
import '../repositories/network_repository.dart';

class SendTrustRequestUseCase {
  final NetworkRepository repository;

  SendTrustRequestUseCase(this.repository);

  Future<TrustRequestEntity> call({
    required UserEntity fromUser,
    required String toPhone,
  }) {
    return repository.sendTrustRequest(fromUser: fromUser, toPhone: toPhone);
  }
}
