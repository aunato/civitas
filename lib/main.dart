import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'app.dart';
import 'core/constants/app_colors.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';

/// Punto de entrada principal de la aplicación móvil CIVITAS
void main() async {
  // 1. Asegurar la vinculación correcta de los canales de plataforma de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Fijar estilo de barra de estado institucional
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 3. Forzar Hybrid Composition en Android para evitar pantallas negras o grises en Google Maps
  try {
    final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
      debugPrint('[CIVITAS-Main] Google Maps Android inicializado con Hybrid Composition y renderer latest.');
    }
  } catch (e) {
    debugPrint('[CIVITAS-Main] Advertencia inicializando Google Maps Android: $e');
  }

  // 4. Inicialización asíncrona de Firebase (Firebase Core y Firestore Offline Persistence)
  debugPrint('[CIVITAS-Main] Iniciando servicios en la nube...');
  await FirebaseService.initialize();

  // 4. Inicialización asíncrona de Notificaciones Push (Firebase Cloud Messaging - FCM)
  if (FirebaseService.isInitialized) {
    debugPrint('[CIVITAS-Main] Configurando Firebase Cloud Messaging...');
    await NotificationService.initialize();
  } else {
    debugPrint('[CIVITAS-Main] Firebase no disponible en este arranque. Iniciando en modo local/fallback.');
  }

  // 5. Ejecutar la aplicación
  runApp(const CivitasApp());
}
