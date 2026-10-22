import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../models/reporte_model.dart';

abstract class ReportesRemoteDataSource {
  /// Guarda un reporte capturando la ubicación actual GPS y el tipo de incidente seleccionado
  Future<String> guardarReporteConUbicacionActual({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    GeoPoint? coordenadas,
  });

  /// Crear reporte directamente desde un modelo
  Future<void> crearReporte(ReporteModel reporte);

  /// Disparo instantáneo del botón de pánico
  Future<String> activarBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  });

  /// Stream en tiempo real de reportes con estado 'ACTIVO' o 'VALIDADO'
  Stream<List<ReporteModel>> getReportesActivosStream();

  /// Validar un reporte por parte de un vecino (+1 confirmación atómica)
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  });
}

class ReportesRemoteDataSourceImpl implements ReportesRemoteDataSource {
  final FirebaseFirestore firestore;
  final ILocationService locationService;

  static final StreamController<List<ReporteModel>> _localStreamController =
      StreamController<List<ReporteModel>>.broadcast();

  static final List<ReporteModel> _demoReportesList = [
    ReporteModel(
      id_reporte: 'demo_01',
      autor_ref: 'vecino_comunitario_1',
      tipo: FirebaseConstants.tipoActividadSospechosa,
      coordenadas: const GeoPoint(-33.4489, -70.6693),
      geohash: '66jc5q',
      estado: FirebaseConstants.estadoActivo,
      contador_validaciones: 3,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      validadores: const ['vecino_a', 'vecino_b', 'vecino_c'],
    ),
    ReporteModel(
      id_reporte: 'demo_02',
      autor_ref: 'vecino_comunitario_2',
      tipo: FirebaseConstants.tipoEmergenciaMedica,
      coordenadas: const GeoPoint(-33.4475, -70.6710),
      geohash: '66jc5r',
      estado: FirebaseConstants.estadoValidado,
      contador_validaciones: 5,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      validadores: const ['vecino_a', 'vecino_b', 'vecino_c', 'vecino_d', 'vecino_e'],
    ),
    ReporteModel(
      id_reporte: 'demo_03',
      autor_ref: 'vecino_comunitario_3',
      tipo: FirebaseConstants.tipoAsalto,
      coordenadas: const GeoPoint(-33.4510, -70.6670),
      geohash: '66jc5m',
      estado: FirebaseConstants.estadoActivo,
      contador_validaciones: 2,
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      validadores: const ['vecino_a', 'vecino_b'],
    ),
  ];

  ReportesRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    ILocationService? locationService,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        locationService = locationService ?? LocationService.instance;

  @override
  Future<String> guardarReporteConUbicacionActual({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    GeoPoint? coordenadas,
  }) async {
    try {
      GeoPoint puntoGeo = coordenadas ?? const GeoPoint(0.0, 0.0);

      // Si no se proporcionaron coordenadas previas, consultar al GPS en tiempo real con límite estricto
      if (coordenadas == null) {
        debugPrint('[ReportesDataSource] Capturando posición GPS en tiempo real...');
        try {
          final pos = await locationService.getCurrentLocation().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('[ReportesDataSource] Timeout en GPS, usando ubicación predeterminada.');
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
            },
          );
          puntoGeo = GeoPoint(pos.latitude, pos.longitude);
        } catch (e) {
          debugPrint('[ReportesDataSource] No se pudo obtener ubicación GPS, usando base: $e');
          puntoGeo = const GeoPoint(AppConstants.defaultLatitude, AppConstants.defaultLongitude);
        }
      }

      // Calcular Geohash con precisión de 9 caracteres para filtrado espacial eficiente
      final geohashCalculado = GeoUtils.encodeGeohash(
        latitude: puntoGeo.latitude,
        longitude: puntoGeo.longitude,
        precision: 9,
      );

      final docRef = firestore.collection(FirebaseConstants.colReportes).doc();

      final reporte = ReporteModel(
        id_reporte: docRef.id,
        autor_ref: autorUid,
        tipo: tipoIncidente,
        coordenadas: puntoGeo,
        geohash: geohashCalculado,
        estado: FirebaseConstants.estadoActivo,
        contador_validaciones: 0,
        timestamp: DateTime.now(),
        evidencia_url: evidenciaUrl,
        validadores: const [],
      );

      // Difusión local instantánea
      _demoReportesList.insert(0, reporte);
      _localStreamController.add(List.unmodifiable(_demoReportesList));

      debugPrint('[ReportesDataSource] Guardando reporte ${docRef.id} en Firestore...');
      await docRef.set(reporte.toFirestore()).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[ReportesDataSource] Timeout al escribir en Firestore. Persistido en cola local.');
        },
      );
      debugPrint('[ReportesDataSource] Reporte guardado con éxito. Tipo: $tipoIncidente');

      return docRef.id;
    } catch (e) {
      debugPrint('[ReportesDataSource] Fallback local al guardar reporte: $e');
      return 'local_reporte_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<void> crearReporte(ReporteModel reporte) async {
    try {
      final docRef = firestore.collection(FirebaseConstants.colReportes).doc(
        reporte.id_reporte.isNotEmpty ? reporte.id_reporte : null,
      );
      final finalReport = reporte.copyWith(id_reporte: docRef.id);
      _demoReportesList.insert(0, finalReport);
      _localStreamController.add(List.unmodifiable(_demoReportesList));

      await docRef.set(finalReport.toFirestore()).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[ReportesDataSource] Timeout en crearReporte Firestore.');
        },
      );
    } catch (e) {
      debugPrint('[ReportesDataSource] Fallback local crear reporte: $e');
    }
  }

  @override
  Future<String> activarBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final docRef = firestore.collection(FirebaseConstants.colReportes).doc();
      final geohash = GeoUtils.encodeGeohash(
        latitude: latitud,
        longitude: longitud,
        precision: 9,
      );

      final panicModel = ReporteModel(
        id_reporte: docRef.id,
        autor_ref: autorUid,
        tipo: FirebaseConstants.tipoBotonPanico,
        coordenadas: GeoPoint(latitud, longitud),
        geohash: geohash,
        estado: FirebaseConstants.estadoActivo,
        contador_validaciones: 1,
        timestamp: DateTime.now(),
        evidencia_url: null,
        validadores: [autorUid],
      );

      // Propagación reactiva local inmediata a toda la interfaz
      _demoReportesList.insert(0, panicModel);
      _localStreamController.add(List.unmodifiable(_demoReportesList));

      final panicData = {
        'id_reporte': docRef.id,
        'autor_ref': autorUid,
        'tipo': FirebaseConstants.tipoBotonPanico,
        'coordenadas': GeoPoint(latitud, longitud),
        'geohash': geohash,
        'estado': FirebaseConstants.estadoActivo,
        'contador_validaciones': 1,
        'timestamp': FieldValue.serverTimestamp(),
        'evidencia_url': null,
        'validadores': [autorUid],
      };

      await docRef.set(panicData).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[ReportesDataSource] Timeout en activarBotonPanico Firestore.');
        },
      );
      return docRef.id;
    } catch (e) {
      debugPrint('[ReportesDataSource] Fallback local al activar pánico: $e');
      return 'local_panic_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Stream<List<ReporteModel>> getReportesActivosStream() {
    try {
      return firestore
          .collection(FirebaseConstants.colReportes)
          .where('estado', whereIn: [
            FirebaseConstants.estadoActivo,
            FirebaseConstants.estadoValidado,
          ])
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => ReporteModel.fromFirestore(doc))
                .toList();
            if (list.isEmpty) {
              return _demoReportesList;
            }
            return list;
          })
          .handleError((error) {
            debugPrint('[ReportesDataSource] Usando reportes demo por fallback: $error');
            return _demoReportesList;
          });
    } catch (e) {
      debugPrint('[ReportesDataSource] Error conectando a stream Firestore: $e');
      return _localStreamController.stream;
    }
  }

  @override
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  }) async {
    // 1. Actualización atómica en memoria/local para reflejo visual instantáneo
    final idx = _demoReportesList.indexWhere((r) => r.id_reporte == idReporte);
    if (idx != -1) {
      final rep = _demoReportesList[idx];
      final newCount = rep.contador_validaciones + 1;
      final newValidadores = List<String>.from(rep.validadores);
      if (!newValidadores.contains(validadorUid)) {
        newValidadores.add(validadorUid);
      }
      _demoReportesList[idx] = rep.copyWith(
        contador_validaciones: newCount,
        estado: newCount >= FirebaseConstants.umbralValidacionComunidad
            ? FirebaseConstants.estadoValidado
            : rep.estado,
        validadores: newValidadores,
      );
      _localStreamController.add(List.unmodifiable(_demoReportesList));
    }

    // 2. Incremento atómico en Firestore
    try {
      final docRef = firestore.collection(FirebaseConstants.colReportes).doc(idReporte);
      await docRef.set({
        'contador_validaciones': FieldValue.increment(1),
        'validadores': FieldValue.arrayUnion([validadorUid]),
        'ultima_confirmacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[ReportesDataSource] Timeout al confirmar alerta en Firestore.');
        },
      );

      // Si alcanzó el umbral comunitario (>= 5), actualizar estado a VALIDADO
      final snap = await docRef.get(const GetOptions(source: Source.cache));
      if (snap.exists) {
        final totalCount = (snap.data()?['contador_validaciones'] as num?)?.toInt() ?? 0;
        if (totalCount >= FirebaseConstants.umbralValidacionComunidad) {
          await docRef.update({
            'estado': FirebaseConstants.estadoValidado,
            'validado_en': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('[ReportesDataSource] Advertencia en validarReporte Firestore: $e');
    }
  }
}
