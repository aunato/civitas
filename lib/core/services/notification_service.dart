import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firebase_constants.dart';
import '../utils/geo_utils.dart';

/// Handler de nivel superior obligatorio para mensajes en segundo plano (Background/Terminated).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM-Background] Mensaje recibido en background: ${message.messageId}');
  debugPrint('[FCM-Background] Data: ${message.data}');
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  static String? _currentSector;
  static final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream reactivo para capturar alertas en primer plano dentro de la app
  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  /// Inicializa los oyentes de notificaciones push y solicita permisos (Android 13+ / iOS).
  static Future<void> initialize() async {
    try {
      // 1. Registrar handler para segundo plano
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Solicitar permisos de notificación (Android 13+ y iOS)
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCM] Estado de autorización: ${settings.authorizationStatus}');

      // 3. Obtener Token FCM para registrar en Firestore
      _fcmToken = await _messaging.getToken();
      debugPrint('[FCM] FCM Token obtenido: $_fcmToken');

      // 4. Suscribirse a los canales globales de alertas ciudadanas
      try {
        await _messaging.subscribeToTopic('alertas_comunitarias');
        await _messaging.subscribeToTopic('alertas_emergencias');
        await _messaging.subscribeToTopic('alertas_validadas');
        debugPrint('[FCM] Suscripción a tópicos comunitarios completada.');
      } catch (e) {
        debugPrint('[FCM] Advertencia al suscribir a tópicos base: $e');
      }

      // 5. Escuchar cambios o renovaciones de token
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM] FCM Token renovado: $newToken');
      });

      // 6. Manejo de mensajes cuando la app está en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM-Foreground] Alerta recibida: ${message.notification?.title}');
        debugPrint('[FCM-Foreground] Cuerpo: ${message.notification?.body}');
        debugPrint('[FCM-Foreground] Data: ${message.data}');
        _foregroundMessageController.add(message);
      });

      // 7. Manejo de interacción cuando el usuario toca la notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM-Interaction] Notificación abierta por el usuario: ${message.data}');
        _foregroundMessageController.add(message);
      });
    } catch (e) {
      debugPrint('[FCM] Error inicializando Firebase Messaging: $e');
    }
  }

  /// Actualiza la posición del usuario en Firestore y gestiona la suscripción dinámica al sector (geofencing)
  static Future<void> updateUserLocationAndSector({
    required String uid,
    required double latitude,
    required double longitude,
  }) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase no inicializado en este entorno (test/mock). Omitiendo sincronización remota.');
      return;
    }
    try {
      final geohash = GeoUtils.encodeGeohash(
        latitude: latitude,
        longitude: longitude,
        precision: 9,
      );
      final sector = geohash.length >= 5 ? geohash.substring(0, 5) : geohash;

      // Actualizar suscripción temática de sector si cambió de cuadrante
      if (_currentSector != sector) {
        if (_currentSector != null) {
          try {
            await _messaging.unsubscribeFromTopic('sector_$_currentSector');
          } catch (_) {}
        }
        try {
          await _messaging.subscribeToTopic('sector_$sector');
          _currentSector = sector;
          debugPrint('[FCM] Suscrito dinámicamente a cuadrante: sector_$sector');
        } catch (e) {
          debugPrint('[FCM] Error al suscribir a sector_$sector: $e');
        }
      }

      // Sincronizar en Firestore para permitir geofencing directo desde Cloud Functions
      final updateData = <String, dynamic>{
        'uid': uid,
        'ultima_ubicacion': GeoPoint(latitude, longitude),
        'latitud': latitude,
        'longitud': longitude,
        'geohash': geohash,
        'sector': sector,
        'actualizado_en': FieldValue.serverTimestamp(),
      };

      if (_fcmToken != null) {
        updateData['fcm_token'] = _fcmToken;
      }

      await FirebaseFirestore.instance
          .collection(FirebaseConstants.colUsuarios)
          .doc(uid)
          .set(updateData, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('[FCM] Timeout al sincronizar ubicación en Firestore (guardado en caché).');
            },
          );
    } catch (e) {
      debugPrint('[FCM] Advertencia al sincronizar sector y ubicación: $e');
    }
  }

  /// Suscribirse a un tópico comunitario específico de manera manual
  static Future<void> subscribeToSectorTopic(String sectorId) async {
    try {
      await _messaging.subscribeToTopic('sector_$sectorId');
      debugPrint('[FCM] Suscrito manualmente al tópico sector_$sectorId');
    } catch (e) {
      debugPrint('[FCM] Error suscribiendo a tópico: $e');
    }
  }
}
