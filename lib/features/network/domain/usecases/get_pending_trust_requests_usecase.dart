import '../entities/trust_request_entity.dart';
import '../repositories/network_repository.dart';

class GetPendingTrustRequestsUseCase {
  final NetworkRepository repository;

  GetPendingTrustRequestsUseCase(this.repository);

  Future<List<TrustRequestEntity>> call(String userPhone) {
    return repository.getPendingTrustRequests(userPhone);
  }
}
