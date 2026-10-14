import 'dart:math';

class GeoUtils {
  GeoUtils._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Convierte grados a radianes
  static double _toRadians(double degrees) => degrees * (pi / 180.0);

  /// Algoritmo de Haversine para cálculo preciso de distancia esférica en metros
  static double haversineDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadiusMeters = 6371000; // Radio medio de la Tierra en metros

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Codifica coordenadas (latitud, longitud) en un string Geohash en base32 (Morton Order)
  /// Precisión de 7-9 caracteres para indexación geoespacial barrial en Firestore
  static String encodeGeohash({
    required double latitude,
    required double longitude,
    int precision = 9,
  }) {
    double latMin = -90.0, latMax = 90.0;
    double lonMin = -180.0, lonMax = 180.0;
    final StringBuffer hash = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (hash.length < precision) {
      if (isEven) {
        final double mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          lonMin = mid;
        } else {
          lonMax = mid;
        }
      } else {
        final double mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          latMin = mid;
        } else {
          latMax = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        hash.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return hash.toString();
  }

  /// Formatea la distancia para mostrar en tarjetas (ej. "150 m" o "1.2 km")
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
}
