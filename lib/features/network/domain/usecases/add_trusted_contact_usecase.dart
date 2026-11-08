import '../entities/trusted_contact_entity.dart';
import '../repositories/network_repository.dart';

class AddTrustedContactUseCase {
  final NetworkRepository repository;

  AddTrustedContactUseCase(this.repository);

  Future<void> call({
    required String userUid,
    required TrustedContactEntity contact,
  }) {
    return repository.addTrustedContact(userUid: userUid, contact: contact);
  }
}
