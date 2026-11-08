import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.rol,
    required super.reputacion,
    super.nombre,
    super.rut,
    super.ciudad,
    super.telefono,
    super.direccion,
    super.juntaVecinal,
    super.fcmToken,
    super.latitude,
    super.longitude,
    super.estadoVerificacion = 'VERIFICADO',
    super.credencialUrl,
    super.institucion,
    super.placaInstitucional,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    double? lat;
    double? lng;
    if (data['zona_base'] is GeoPoint) {
      final geo = data['zona_base'] as GeoPoint;
      lat = geo.latitude;
      lng = geo.longitude;
    } else if (data['latitud'] != null && data['longitud'] != null) {
      lat = (data['latitud'] as num?)?.toDouble();
      lng = (data['longitud'] as num?)?.toDouble();
    }

    final String rol = data['rol'] as String? ?? 'vecino';
    final bool isInst = rol.toLowerCase() == 'institucional' ||
        rol.toLowerCase() == 'carabineros' ||
        rol.toLowerCase() == 'pdi';

    // Regla de verificación: Si el rol es institucional y no se ha especificado,
    // su estado predeterminado es PENDING_VERIFICATION.
    final String defaultEstado = isInst ? 'PENDING_VERIFICATION' : 'VERIFICADO';
    final String estadoVerificacion =
        data['estado_verificacion'] as String? ?? defaultEstado;

    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      rol: rol,
      reputacion: (data['reputacion'] as num?)?.toInt() ?? 100,
      nombre: data['nombre'] as String?,
      rut: data['rut'] as String?,
      ciudad: data['ciudad'] as String?,
      telefono: data['telefono'] as String?,
      direccion: data['direccion'] as String?,
      juntaVecinal: data['junta_vecinal'] as String?,
      fcmToken: data['fcm_token'] as String?,
      latitude: lat,
      longitude: lng,
      estadoVerificacion: estadoVerificacion,
      credencialUrl: data['credencial_url'] as String?,
      institucion: data['institucion'] as String?,
      placaInstitucional: data['placa_institucional'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'rol': rol,
      'reputacion': reputacion,
      'nombre': nombre,
      'rut': rut,
      'ciudad': ciudad,
      'telefono': telefono,
      'direccion': direccion,
      'junta_vecinal': juntaVecinal,
      'fcm_token': fcmToken,
      'estado_verificacion': estadoVerificacion,
      'credencial_url': credencialUrl,
      'institucion': institucion,
      'placa_institucional': placaInstitucional,
      'actualizado_en': FieldValue.serverTimestamp(),
    };

    if (latitude != null && longitude != null) {
      map['zona_base'] = GeoPoint(latitude!, longitude!);
      map['latitud'] = latitude;
      map['longitud'] = longitude;
    }

    return map;
  }
}
