import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:civitas/core/utils/geo_utils.dart';
import 'package:civitas/features/reportes/data/models/reporte_model.dart';
import 'mocks/mock_reportes_repository.dart';

void main() {
  group('ReporteModel & Firestore Layer - Pruebas Unitarias', () {
    test('1. Inicialización y estructura del modelo ReporteModel', () {
      final now = DateTime.now();
      const geo = GeoPoint(-23.6509, -70.3975);

      final modelo = ReporteModel(
        id_reporte: 'rep_001',
        autor_ref: 'user_123',
        tipo: 'robo_vehiculo',
        coordenadas: geo,
        geohash: '66jbs7m3q',
        estado: 'ACTIVO',
        contador_validaciones: 0,
        timestamp: now,
        evidencia_url: 'https://storage.googleapis.com/civitas/img1.jpg',
      );

      expect(modelo.id_reporte, equals('rep_001'));
      expect(modelo.autor_ref, equals('user_123'));
      expect(modelo.tipo, equals('robo_vehiculo'));
      expect(modelo.coordenadas.latitude, equals(-23.6509));
      expect(modelo.coordenadas.longitude, equals(-70.3975));
      expect(modelo.geohash, equals('66jbs7m3q'));
      expect(modelo.estado, equals('ACTIVO'));
      expect(modelo.contador_validaciones, equals(0));
      expect(modelo.evidencia_url, isNotNull);
    });

    test('2. toFirestore() genera el mapa exacto con FieldValue.serverTimestamp()', () {
      const geo = GeoPoint(-23.6509, -70.3975);
      final modelo = ReporteModel(
        id_reporte: 'rep_002',
        autor_ref: 'user_456',
        tipo: 'actividad_sospechosa',
        coordenadas: geo,
        geohash: '66jbs7m3q',
        timestamp: DateTime.now(),
      );

      final map = modelo.toFirestore();

      expect(map['id_reporte'], equals('rep_002'));
      expect(map['autor_ref'], equals('user_456'));
      expect(map['tipo'], equals('actividad_sospechosa'));
      expect(map['coordenadas'], isA<GeoPoint>());
      expect(map['estado'], equals('ACTIVO'));
      expect(map['contador_validaciones'], equals(0));
      expect(map['timestamp'], isA<FieldValue>());
    });

    test('3. fromMap() deserializa correctamente tipos de Firestore (GeoPoint y Timestamp)', () {
      final fechaPrueba = DateTime(2026, 10, 14, 12, 30);
      final rawData = {
        'id_reporte': 'rep_firestore_99',
        'autor_ref': 'user_vecino_77',
        'tipo': 'emergencia_medica',
        'coordenadas': const GeoPoint(-23.6500, -70.3900),
        'geohash': '66jbs9k11',
        'estado': 'ACTIVO',
        'contador_validaciones': 3,
        'timestamp': Timestamp.fromDate(fechaPrueba),
        'evidencia_url': null,
      };

      final modelo = ReporteModel.fromMap(rawData, id: 'rep_firestore_99');

      expect(modelo.id_reporte, equals('rep_firestore_99'));
      expect(modelo.tipo, equals('emergencia_medica'));
      expect(modelo.latitud, equals(-23.6500));
      expect(modelo.longitud, equals(-70.3900));
      expect(modelo.contador_validaciones, equals(3));
      expect(modelo.timestamp, equals(fechaPrueba));
      expect(modelo.estado, equals('ACTIVO'));
    });

    test('4. Codificación Geohash en base32 para indexación geoespacial', () {
      final hash = GeoUtils.encodeGeohash(
        latitude: -23.6509,
        longitude: -70.3975,
        precision: 9,
      );

      expect(hash, isNotEmpty);
      expect(hash.length, equals(9));
      // Caracteres válidos en base32 (sin a, i, l, o)
      expect(hash.contains(RegExp(r'^[0123456789bcdefghjkmnpqrstuvwxyz]+$')), isTrue);
    });

    test('5. Función de guardado agrega reporte al Stream en tiempo real', () async {
      final mockRepo = MockReportesRepository();

      // Verificar que el stream emite el nuevo reporte tras guardar
      expectLater(
        mockRepo.getReportesActivosStream(),
        emits(predicate<List>((list) =>
            list.length == 1 &&
            list.first.tipo == 'robo_vehiculo' &&
            list.first.estado == 'ACTIVO')),
      );

      final id = await mockRepo.guardarReporteConUbicacionActual(
        autorUid: 'vecino_test_1',
        tipoIncidente: 'robo_vehiculo',
        latitud: -23.6509,
        longitud: -70.3975,
      );

      expect(id, isNotEmpty);
      expect(mockRepo.guardarCalls, equals(1));
    });
  });
}
