import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import '../../domain/entities/trusted_contact_entity.dart';
import '../../domain/entities/trust_request_entity.dart';
import '../../domain/repositories/network_repository.dart';
import '../datasources/contacts_device_datasource.dart';
import '../datasources/network_remote_datasource.dart';
import '../models/trusted_contact_model.dart';
import '../models/trust_request_model.dart';

class NetworkRepositoryImpl implements NetworkRepository {
  final NetworkRemoteDataSource remoteDataSource;
  final ContactsDeviceDataSource deviceDataSource;

  NetworkRepositoryImpl({
    required this.remoteDataSource,
    required this.deviceDataSource,
  });

  @override
  Future<List<TrustedContactEntity>> getTrustedContacts(String userUid) async {
    return await remoteDataSource.getTrustedContacts(userUid);
  }

  @override
  Future<void> addTrustedContact({
    required String userUid,
    required TrustedContactEntity contact,
  }) async {
    final model = TrustedContactModel.fromEntity(contact);
    await remoteDataSource.addTrustedContact(userUid, model);
  }

  @override
  Future<void> removeTrustedContact({
    required String userUid,
    required String contactId,
  }) async {
    await remoteDataSource.removeTrustedContact(userUid, contactId);
  }

  @override
  Future<List<TrustRequestEntity>> getPendingTrustRequests(String userPhone) async {
    return await remoteDataSource.getPendingTrustRequests(userPhone);
  }

  @override
  Stream<List<TrustRequestEntity>> streamPendingTrustRequests(String userPhone) {
    return remoteDataSource.streamPendingTrustRequests(userPhone);
  }

  @override
  Future<TrustRequestEntity> sendTrustRequest({
    required UserEntity fromUser,
    required String toPhone,
  }) async {
    final folio = 'CIVITAS-CL-${fromUser.uid.length >= 6 ? fromUser.uid.substring(0, 6).toUpperCase() : "SEC2026"}';
    final request = TrustRequestModel(
      id: '',
      fromUid: fromUser.uid,
      fromName: fromUser.nombre ?? 'Vecino CIVITAS',
      fromPhone: fromUser.telefono ?? '',
      fromRut: fromUser.rut,
      fromRol: fromUser.rol,
      fromReputacion: fromUser.reputacion,
      fromCredencialFolio: folio,
      toPhone: toPhone.replaceAll(' ', '').replaceAll('-', ''),
      status: 'PENDING',
      createdAt: DateTime.now(),
    );

    return await remoteDataSource.sendTrustRequest(request);
  }

  @override
  Future<void> respondTrustRequest({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  }) async {
    await remoteDataSource.respondTrustRequest(
      requestId: requestId,
      accept: accept,
      respondingUser: respondingUser,
    );
  }

  @override
  Future<List<TrustedContactEntity>> getDevicePhoneContacts() async {
    return await deviceDataSource.getPhoneContacts();
  }

  @override
  Future<List<TrustedContactEntity>> checkRegisteredUsers(List<TrustedContactEntity> contacts) async {
    return await remoteDataSource.checkRegisteredUsers(contacts);
  }

  @override
  Future<bool> requestContactsPermission() async {
    return await deviceDataSource.requestPermission();
  }
}
