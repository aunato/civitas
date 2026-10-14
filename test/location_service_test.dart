import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/core/services/location_service.dart';
import 'package:civitas/core/utils/geo_utils.dart';

void main() {
  group('LocationService & GeoUtils - Pruebas de Cálculo Geodésico', () {
    test('1. Distancia Haversine precisa entre dos puntos', () {
      // Coordenadas fijas de prueba (distancia aproximada ~111 metros en un grado de latitud)
      const lat1 = -23.6500;
      const lon1 = -70.3975;
      const lat2 = -23.6510;
      const lon2 = -70.3975;

      final distance = GeoUtils.haversineDistanceMeters(
        lat1: lat1,
        lon1: lon1,
        lat2: lat2,
        lon2: lon2,
      );

      // 0.001 grados de latitud corresponden a aprox. 111.1 metros
      expect(distance, greaterThan(110.0));
      expect(distance, lessThan(112.5));
    });

    test('2. Validación de radio de alerta comunitaria (500m)', () {
      const userLat = -23.6500;
      const userLng = -70.3975;

      // Punto cercano (~150m)
      const alertCercanaLat = -23.6513;
      const alertCercanaLng = -70.3975;

      // Punto lejano (~2km)
      const alertLejanaLat = -23.6700;
      const alertLejanaLng = -70.3975;

      final isWithin500 = LocationService.isWithinAlertRadius(
        userLat: userLat,
        userLng: userLng,
        alertLat: alertCercanaLat,
        alertLng: alertCercanaLng,
        radiusMeters: 500.0,
      );

      final isFar = LocationService.isWithinAlertRadius(
        userLat: userLat,
        userLng: userLng,
        alertLat: alertLejanaLat,
        alertLng: alertLejanaLng,
        radiusMeters: 500.0,
      );

      expect(isWithin500, isTrue);
      expect(isFar, isFalse);
    });
  });
}
