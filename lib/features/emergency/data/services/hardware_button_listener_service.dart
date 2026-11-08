import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio que intercepta eventos de botones físicos de hardware (Volumen Abajo)
/// para ejecutar el protocolo anti-coacción (Tesis CIVITAS).
///
/// Si el usuario presiona el botón de Volumen Abajo 3 veces en un lapso inferior a 2.5 segundos,
/// se activa de forma instantánea el modo coacción (Silent Duress).
class HardwareButtonListenerService {
  static final HardwareButtonListenerService _instance =
      HardwareButtonListenerService._internal();

  factory HardwareButtonListenerService() => _instance;

  HardwareButtonListenerService._internal();

  final List<DateTime> _volumeDownPressTimestamps = [];

  /// Ventana temporal máxima para registrar las 3 pulsaciones (2.5 segundos)
  final Duration _sequenceWindow = const Duration(milliseconds: 2500);

  bool _isListening = false;
  bool get isListening => _isListening;

  VoidCallback? _onCoercionTriggered;

  final StreamController<void> _coercionTriggerController =
      StreamController<void>.broadcast();

  Stream<void> get onCoercionTriggeredStream =>
      _coercionTriggerController.stream;

  /// Inicia la escucha de teclas físicas en el dispositivo
  void startListening({VoidCallback? onCoercionTriggered}) {
    if (_isListening) return;
    _onCoercionTriggered = onCoercionTriggered;
    _isListening = true;
    _volumeDownPressTimestamps.clear();

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    debugPrint(
      '[HardwareListener] 🛡️ Oyente de botones físicos anti-coacción activado (Patrón: 3 pulsaciones Volumen Abajo).',
    );
  }

  /// Detiene la escucha de eventos de hardware
  void stopListening() {
    if (!_isListening) return;
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _isListening = false;
    _volumeDownPressTimestamps.clear();
    debugPrint('[HardwareListener] Oyente de botones físicos detenido.');
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isVolumeDown = key == LogicalKeyboardKey.audioVolumeDown ||
          // Para pruebas rápidas en emulador / escritorio: Tecla 'v'
          key == LogicalKeyboardKey.keyV;

      if (isVolumeDown) {
        registerVolumeDownPress();
        return true; // Evento consumido
      }
    }
    return false;
  }

  /// Registra una pulsación de botón de volumen y evalúa si se cumple el patrón de 3 toques
  void registerVolumeDownPress() {
    final now = DateTime.now();

    // Eliminar toques antiguos fuera de la ventana de 2.5s
    _volumeDownPressTimestamps.removeWhere(
      (ts) => now.difference(ts) > _sequenceWindow,
    );

    _volumeDownPressTimestamps.add(now);
    debugPrint(
      '[HardwareListener] Pulsación de volumen registrada (${_volumeDownPressTimestamps.length}/3)',
    );

    if (_volumeDownPressTimestamps.length >= 3) {
      _volumeDownPressTimestamps.clear();
      debugPrint(
        '[HardwareListener] 🚨 ¡PATRÓN ANTI-COACCIÓN DETECTADO! Disparando protocolo de seguridad silencioso.',
      );
      _onCoercionTriggered?.call();
      _coercionTriggerController.add(null);
    }
  }

  /// Método explícito para pruebas unitarias sin hardware real
  @visibleForTesting
  void simulateVolumeDownSequence() {
    registerVolumeDownPress();
    registerVolumeDownPress();
    registerVolumeDownPress();
  }

  void dispose() {
    stopListening();
    _coercionTriggerController.close();
  }
}
