import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/network/domain/entities/trusted_contact_entity.dart';
import 'package:civitas/features/network/domain/entities/trust_request_entity.dart';
import 'package:civitas/features/network/domain/repositories/network_repository.dart';

class MockNetworkRepository implements NetworkRepository {
  final List<TrustedContactEntity> trustedContacts = [];
  final List<TrustRequestEntity> pendingRequests = [];
  final List<TrustedContactEntity> deviceContacts = [
    TrustedContactEntity(
      id: 'mock_dev_1',
      name: 'Don Carlos (Vecino Pasaje A)',
      phone: '+56912345678',
      relationship: 'Vecino de Confianza',
      isVerified: true,
      addedAt: DateTime(2026, 11, 8),
    ),
    TrustedContactEntity(
      id: 'mock_dev_2',
      name: 'María Segura (Comité Vecinal)',
      phone: '+56987654321',
      relationship: 'Comité de Seguridad',
      isVerified: true,
      addedAt: DateTime(2026, 11, 8),
    ),
  ];

  @override
  Future<List<TrustedContactEntity>> getTrustedContacts(String userUid) async {
    return List.from(trustedContacts);
  }

  @override
  Future<void> addTrustedContact({
    required String userUid,
    required TrustedContactEntity contact,
  }) async {
    trustedContacts.removeWhere((c) => c.id == contact.id || c.phone == contact.phone);
    trustedContacts.add(contact);
  }

  @override
  Future<void> removeTrustedContact({
    required String userUid,
    required String contactId,
  }) async {
    trustedContacts.removeWhere((c) => c.id == contactId);
  }

  @override
  Future<List<TrustRequestEntity>> getPendingTrustRequests(String userPhone) async {
    return pendingRequests.where((r) => r.isPending).toList();
  }

  @override
  Future<TrustRequestEntity> sendTrustRequest({
    required UserEntity fromUser,
    required String toPhone,
  }) async {
    final folio = 'CIVITAS-CL-${fromUser.uid.length >= 6 ? fromUser.uid.substring(0, 6).toUpperCase() : "SEC2026"}';
    final request = TrustRequestEntity(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      fromUid: fromUser.uid,
      fromName: fromUser.nombre,
      fromPhone: fromUser.telefono,
      fromRut: fromUser.rut,
      fromRol: fromUser.rol,
      fromReputacion: fromUser.reputacion,
      fromCredencialFolio: folio,
      toPhone: toPhone,
      status: 'PENDING',
      createdAt: DateTime.now(),
    );
    pendingRequests.add(request);
    return request;
  }

  @override
  Future<void> respondTrustRequest({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  }) async {
    final index = pendingRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = pendingRequests[index];
      pendingRequests[index] = req.copyWith(
        status: accept ? 'ACCEPTED' : 'REJECTED',
        toUid: respondingUser.uid,
        respondedAt: DateTime.now(),
      );

      if (accept) {
        trustedContacts.add(
          TrustedContactEntity(
            id: req.fromUid,
            name: req.fromName,
            phone: req.fromPhone,
            relationship: 'Red CIVITAS Verificada',
            isVerified: true,
            addedAt: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  Future<List<TrustedContactEntity>> getDevicePhoneContacts() async {
    return List.from(deviceContacts);
  }

  @override
  Future<bool> requestContactsPermission() async {
    return true;
  }
}
