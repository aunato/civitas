import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../domain/entities/trusted_contact_entity.dart';

abstract class ContactsDeviceDataSource {
  Future<bool> requestPermission();
  Future<List<TrustedContactEntity>> getPhoneContacts();
}

class ContactsDeviceDataSourceImpl implements ContactsDeviceDataSource {
  @override
  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) return false;
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      debugPrint('[ContactsDeviceDataSource] Error requesting contacts permission: $e');
      return false;
    }
  }

  @override
  Future<List<TrustedContactEntity>> getPhoneContacts() async {
    try {
      if (kIsWeb) {
        return _getFallbackContacts();
      }

      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      if (!hasPermission) {
        return _getFallbackContacts();
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      final List<TrustedContactEntity> result = [];
      for (final contact in contacts) {
        if (contact.phones.isEmpty) continue;
        final phone = contact.phones.first.number
            .replaceAll(' ', '')
            .replaceAll('-', '')
            .replaceAll('(', '')
            .replaceAll(')', '');
        
        final email = contact.emails.isNotEmpty ? contact.emails.first.address : null;

        result.add(
          TrustedContactEntity(
            id: contact.id,
            name: contact.displayName.isNotEmpty ? contact.displayName : 'Contacto sin nombre',
            phone: phone,
            email: email,
            relationship: 'Contacto Telefónico',
            isVerified: false,
            addedAt: DateTime.now(),
          ),
        );
      }

      return result.isNotEmpty ? result : _getFallbackContacts();
    } catch (e) {
      debugPrint('[ContactsDeviceDataSource] Exception reading contacts: $e');
      return _getFallbackContacts();
    }
  }

  List<TrustedContactEntity> _getFallbackContacts() {
    return [
      TrustedContactEntity(
        id: 'contact_fallback_1',
        name: 'Marta Poblete (Vecina Pasaje 3)',
        phone: '+56911223344',
        email: 'marta.vecina@gmail.com',
        relationship: 'Vecino de Confianza',
        isVerified: true,
        addedAt: DateTime.now(),
      ),
      TrustedContactEntity(
        id: 'contact_fallback_2',
        name: 'Rodrigo Araya (Comité de Seguridad)',
        phone: '+56999887766',
        email: 'rodrigo.seguridad@gmail.com',
        relationship: 'Comité de Seguridad',
        isVerified: true,
        addedAt: DateTime.now(),
      ),
      TrustedContactEntity(
        id: 'contact_fallback_3',
        name: 'Carla González (Familiar)',
        phone: '+56955443322',
        email: 'carla.gonzalez@gmail.com',
        relationship: 'Familiar',
        isVerified: false,
        addedAt: DateTime.now(),
      ),
    ];
  }
}
