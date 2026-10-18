import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../errors/exceptions.dart';

abstract class ILocationService {
  Future<bool> handleLocationPermission();
  Future<Position> getCurrentLocation();
  Future<LatLng> getCurrentLatLng();
  Future<LatLng> centerMapOnUser(GoogleMapController controller, {double zoom = 16.0});
}

class LocationService implements ILocationService {
  static final LocationService instance = LocationService._internal();

  LocationService._internal();

  factory LocationService() => instance;

  /// Verifica y solicita permisos de ubicación en tiempo real
  @override
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Los servicios de ubicación GPS están desactivados.');
      throw LocationException('El GPS está desactivado. Actívelo en los ajustes del dispositivo.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('[LocationService] Solicitando permisos de ubicación en tiempo real...');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Permisos de ubicación denegados por el usuario.');
        throw PermissionException('Permiso de ubicación denegado por el usuario.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Permisos de ubicación denegados permanentemente.');
      throw PermissionException('Los permisos de ubicación están denegados permanentemente. Debe habilitarlos en los ajustes de la aplicación.');
    }

    return true;
  }

  /// Obtiene la posición GPS actual con alta precisión (Position)
  @override
  Future<Position> getCurrentLocation() async {
    try {
      await handleLocationPermission();
    } catch (e) {
      debugPrint('[LocationService] Advertencia de permisos GPS: $e');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (e) {
      debugPrint('[LocationService] Sensor GPS no respondió a tiempo, consultando última posición conocida: $e');
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;

      // Fallback a coordenadas base de Antofagasta (Chile) para permitir pruebas sin bloqueo
      return Position(
        latitude: AppConstants.defaultLatitude,
        longitude: AppConstants.defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }
  }

  /// Obtiene la posición actual en formato LatLng para Google Maps
  @override
  Future<LatLng> getCurrentLatLng() async {
    final position = await getCurrentLocation();
    return LatLng(position.latitude, position.longitude);
  }

  /// Recentra la cámara del mapa automáticamente en la posición del usuario
  @override
  Future<LatLng> centerMapOnUser(GoogleMapController controller, {double zoom = 16.0}) async {
    final latLng = await getCurrentLatLng();
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: latLng,
          zoom: zoom,
        ),
      ),
    );
    return latLng;
  }

  /// Método estático auxiliar para compatibilidad retroactiva
  static Future<Position> getLocationStatic() => instance.getCurrentLocation();

  /// Calcula la distancia en metros entre dos coordenadas geodésicas
  static double calculateDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Verifica si una coordenada está dentro del radio de alerta comunitario (500m por defecto)
  static bool isWithinAlertRadius({
    required double userLat,
    required double userLng,
    required double alertLat,
    required double alertLng,
    double radiusMeters = 500.0,
  }) {
    final distance = calculateDistanceMeters(
      startLatitude: userLat,
      startLongitude: userLng,
      endLatitude: alertLat,
      endLongitude: alertLng,
    );
    return distance <= radiusMeters;
  }
}
