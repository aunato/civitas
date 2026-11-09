import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../reportes/domain/entities/reporte_entity.dart';

class ProximityAlertEvent {
  final ReporteEntity reporte;
  final double distanceMeters;
  final DateTime timestamp;

  const ProximityAlertEvent({
    required this.reporte,
    required this.distanceMeters,
    required this.timestamp,
  });
}

/// Servicio de Geofencing y Alertas de Proximidad en Tiempo Real.
/// Utiliza el algoritmo de Haversine para evaluar transmisiones de Firestore en vivo
/// y disparar notificaciones locales de alta prioridad al ingresar al radio de 500m.
class ProximityAlertService {
  static final ProximityAlertService _instance = ProximityAlertService._internal();
  factory ProximityAlertService() => _instance;
  ProximityAlertService._internal();

  static const double alertRadiusMeters = 500.0;

  final Set<String> _notifiedReportIds = {};
  final StreamController<ProximityAlertEvent> _alertController =
      StreamController<ProximityAlertEvent>.broadcast();

  Stream<ProximityAlertEvent> get onProximityAlert => _alertController.stream;

  /// Evalúa la proximidad de los incidentes recibidos en el Stream respecto a la posición GPS del usuario.
  List<ProximityAlertEvent> evaluateAlertsProximity({
    required double userLat,
    required double userLng,
    required List<ReporteEntity> reportes,
    required String currentUserId,
  }) {
    final List<ProximityAlertEvent> triggeredEvents = [];

    for (final reporte in reportes) {
      // Ignorar reportes propios para evitar auto-alertas
      if (reporte.autorRef == currentUserId) continue;

      // Cálculo de distancia precisa esférica con Haversine
      final distance = GeoUtils.haversineDistanceMeters(
        lat1: userLat,
        lon1: userLng,
        lat2: reporte.latitud,
        lon2: reporte.longitud,
      );

      // Si se encuentra dentro del radio crítico de 500 metros
      if (distance <= alertRadiusMeters) {
        if (!_notifiedReportIds.contains(reporte.idReporte)) {
          _notifiedReportIds.add(reporte.idReporte);

          final event = ProximityAlertEvent(
            reporte: reporte,
            distanceMeters: distance,
            timestamp: DateTime.now(),
          );

          triggeredEvents.add(event);
          _alertController.add(event);

          // Retroalimentación háptica / vibración de alta prioridad
          _triggerHapticAlert();

          debugPrint(
            '[ProximityAlertService] ⚠️ Alerta de proximidad disparada: "${reporte.tipo}" a ${distance.toStringAsFixed(1)}m (Radio: 500m).',
          );
        }
      } else {
        // Si el usuario se alejó más allá de 700m, permite re-alertar en caso de reingreso futuro
        if (distance > 700.0) {
          _notifiedReportIds.remove(reporte.idReporte);
        }
      }
    }

    return triggeredEvents;
  }

  void _triggerHapticAlert() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Limpia el registro de notificaciones emitidas (útil para pruebas o cambio de sector)
  void reset() {
    _notifiedReportIds.clear();
  }

  void dispose() {
    _alertController.close();
  }
}
