import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

  /// Inicializa los oyentes de notificaciones push y solicita permisos (Android 13+ / iOS).
  static Future<void> initialize() async {
    try {
      // Registrar handler para segundo plano
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Solicitar permisos de notificación (Android 13+ y iOS)
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

      // Obtener Token FCM para registrar en Firestore (Colección usuarios -> fcm_token)
      _fcmToken = await _messaging.getToken();
      debugPrint('[FCM] FCM Token obtenido: $_fcmToken');

      // Escuchar cambios de token
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCM] FCM Token renovado: $newToken');
        // Aquí se actualiza el token en el perfil del usuario en Firestore
      });

      // Manejo de mensajes cuando la app está en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM-Foreground] Alerta recibida: ${message.notification?.title}');
        debugPrint('[FCM-Foreground] Cuerpo: ${message.notification?.body}');
        debugPrint('[FCM-Foreground] Payload: ${message.data}');
      });

      // Manejo de interacción cuando el usuario toca la notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM-Interaction] Notificación abierta por el usuario: ${message.data}');
      });
    } catch (e) {
      debugPrint('[FCM] Error inicializando Firebase Messaging: $e');
    }
  }

  /// Suscribirse a un tópico comunitario (Ej: sector geográfico o junta de vecinos)
  static Future<void> subscribeToSectorTopic(String sectorId) async {
    try {
      await _messaging.subscribeToTopic('sector_$sectorId');
      debugPrint('[FCM] Suscrito al tópico sector_$sectorId');
    } catch (e) {
      debugPrint('[FCM] Error suscribiendo a tópico: $e');
    }
  }
}
