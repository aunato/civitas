import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  FirebaseService._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Inicialización asíncrona de Firebase con captura segura de excepciones.
  static Future<void> initialize() async {
    if (_isInitialized || Firebase.apps.isNotEmpty) {
      debugPrint('[CIVITAS-Firebase] Firebase ya se encontraba inicializado.');
      _isInitialized = true;
      return;
    }

    try {
      debugPrint('[CIVITAS-Firebase] Iniciando Firebase Core...');
      await Firebase.initializeApp();
      
      // Habilitar persistencia offline para Firestore (Fundamental para contingencias sin red en terreno)
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
      debugPrint('[CIVITAS-Firebase] Firebase inicializado exitosamente.');
    } catch (e, stackTrace) {
      debugPrint('[CIVITAS-Firebase] Error al inicializar Firebase: $e');
      debugPrint('[CIVITAS-Firebase] StackTrace: $stackTrace');
      // No relanzamos para permitir que la app muestre UI de configuración/alerta si falta google-services.json
    }
  }
}
