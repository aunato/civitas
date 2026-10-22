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

    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      rol: data['rol'] as String? ?? 'vecino',
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
