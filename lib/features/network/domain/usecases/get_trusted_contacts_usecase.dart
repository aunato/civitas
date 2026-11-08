import '../entities/trusted_contact_entity.dart';
import '../repositories/network_repository.dart';

class GetTrustedContactsUseCase {
  final NetworkRepository repository;

  GetTrustedContactsUseCase(this.repository);

  Future<List<TrustedContactEntity>> call(String userUid) {
    return repository.getTrustedContacts(userUid);
  }
}
