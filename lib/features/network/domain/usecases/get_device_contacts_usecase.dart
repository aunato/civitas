import '../entities/trusted_contact_entity.dart';
import '../repositories/network_repository.dart';

class GetDeviceContactsUseCase {
  final NetworkRepository repository;

  GetDeviceContactsUseCase(this.repository);

  Future<List<TrustedContactEntity>> call() {
    return repository.getDevicePhoneContacts();
  }

  Future<bool> requestPermission() {
    return repository.requestContactsPermission();
  }
}
