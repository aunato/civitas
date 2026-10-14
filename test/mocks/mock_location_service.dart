import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:civitas/core/services/location_service.dart';

class MockLocationService implements ILocationService {
  bool permissionGranted = true;
  bool isServiceEnabled = true;
  LatLng mockCoordinates = const LatLng(-23.6509, -70.3975);
  int handlePermissionCalls = 0;
  int getCurrentLatLngCalls = 0;
  int centerMapCalls = 0;

  @override
  Future<bool> handleLocationPermission() async {
    handlePermissionCalls++;
    if (!isServiceEnabled) {
      throw Exception('GPS desactivado');
    }
    if (!permissionGranted) {
      throw Exception('Permisos denegados');
    }
    return true;
  }

  @override
  Future<Position> getCurrentLocation() async {
    await handleLocationPermission();
    return Position(
      latitude: mockCoordinates.latitude,
      longitude: mockCoordinates.longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 10.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  @override
  Future<LatLng> getCurrentLatLng() async {
    getCurrentLatLngCalls++;
    await handleLocationPermission();
    return mockCoordinates;
  }

  @override
  Future<LatLng> centerMapOnUser(GoogleMapController controller, {double zoom = 16.0}) async {
    centerMapCalls++;
    return await getCurrentLatLng();
  }
}
