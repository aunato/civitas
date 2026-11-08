import '../repositories/network_repository.dart';

class RemoveTrustedContactUseCase {
  final NetworkRepository repository;

  RemoveTrustedContactUseCase(this.repository);

  Future<void> call({
    required String userUid,
    required String contactId,
  }) {
    return repository.removeTrustedContact(userUid: userUid, contactId: contactId);
  }
}
