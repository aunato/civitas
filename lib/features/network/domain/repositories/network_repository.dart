import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import '../entities/trusted_contact_entity.dart';
import '../entities/trust_request_entity.dart';

abstract class NetworkRepository {
  /// Obtiene los contactos de la red de confianza del usuario
  Future<List<TrustedContactEntity>> getTrustedContacts(String userUid);

  /// Agrega un nuevo contacto a la red de confianza
  Future<void> addTrustedContact({
    required String userUid,
    required TrustedContactEntity contact,
  });

  /// Elimina un contacto de la red de confianza
  Future<void> removeTrustedContact({
    required String userUid,
    required String contactId,
  });

  /// Obtiene las solicitudes de confianza pendientes dirigidas al número de teléfono del usuario
  Future<List<TrustRequestEntity>> getPendingTrustRequests(String userPhone);

  /// Envía una solicitud de confianza vecinal con la credencial de CIVITAS del usuario
  Future<TrustRequestEntity> sendTrustRequest({
    required UserEntity fromUser,
    required String toPhone,
  });

  /// Responde una solicitud de confianza (Aceptar / Rechazar)
  Future<void> respondTrustRequest({
    required String requestId,
    required bool accept,
    required UserEntity respondingUser,
  });

  /// Lee los contactos del dispositivo móvil usando la libreta de direcciones
  Future<List<TrustedContactEntity>> getDevicePhoneContacts();

  /// Solicita permisos para acceder a la libreta de contactos
  Future<bool> requestContactsPermission();
}
