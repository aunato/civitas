import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.rol,
    required super.reputacion,
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
    }

    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      rol: data['rol'] as String? ?? 'vecino',
      reputacion: (data['reputacion'] as num?)?.toInt() ?? 100,
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
      'fcm_token': fcmToken,
    };

    if (latitude != null && longitude != null) {
      map['zona_base'] = GeoPoint(latitude!, longitude!);
    }

    return map;
  }
}
