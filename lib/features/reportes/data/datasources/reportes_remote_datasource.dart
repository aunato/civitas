import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
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

  /// Validar un reporte por parte de un vecino (+1 confirmación)
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  });
}

class ReportesRemoteDataSourceImpl implements ReportesRemoteDataSource {
  final FirebaseFirestore firestore;
  final ILocationService locationService;

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

      // Si no se proporcionaron coordenadas previas, consultar al GPS en tiempo real
      if (coordenadas == null) {
        debugPrint('[ReportesDataSource] Capturando posición GPS en tiempo real...');
        final pos = await locationService.getCurrentLocation();
        puntoGeo = GeoPoint(pos.latitude, pos.longitude);
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
      );

      debugPrint('[ReportesDataSource] Guardando reporte ${docRef.id} en Firestore...');
      await docRef.set(reporte.toFirestore());
      debugPrint('[ReportesDataSource] Reporte guardado con éxito. Tipo: $tipoIncidente');

      return docRef.id;
    } catch (e) {
      debugPrint('[ReportesDataSource] Error al guardar reporte: $e');
      throw ServerException('Error al guardar reporte en Cloud Firestore: $e');
    }
  }

  @override
  Future<void> crearReporte(ReporteModel reporte) async {
    try {
      final docRef = firestore.collection(FirebaseConstants.colReportes).doc(
        reporte.id_reporte.isNotEmpty ? reporte.id_reporte : null,
      );
      final finalReport = reporte.copyWith(id_reporte: docRef.id);
      await docRef.set(finalReport.toFirestore());
    } catch (e) {
      throw ServerException('Error al registrar incidente: $e');
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
      };

      await docRef.set(panicData);
      return docRef.id;
    } catch (e) {
      throw ServerException('Error al disparar el Botón de Pánico: $e');
    }
  }

  @override
  Stream<List<ReporteModel>> getReportesActivosStream() {
    return firestore
        .collection(FirebaseConstants.colReportes)
        .where('estado', whereIn: [
          FirebaseConstants.estadoActivo,
          FirebaseConstants.estadoValidado,
        ])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ReporteModel.fromFirestore(doc))
              .toList();
        });
  }

  @override
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  }) async {
    try {
      final docRef = firestore.collection(FirebaseConstants.colReportes).doc(idReporte);
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw ServerException('El reporte ya no existe o fue retirado.');
        }

        final currentValidaciones = (snapshot.get('contador_validaciones') as num?)?.toInt() ?? 0;
        final nextCount = currentValidaciones + 1;

        final updates = <String, dynamic>{
          'contador_validaciones': nextCount,
        };

        // Regla de confirmación vecinal: al llegar a 5 validaciones comunitarias pasa a VALIDADO
        if (nextCount >= FirebaseConstants.umbralValidacionComunidad) {
          updates['estado'] = FirebaseConstants.estadoValidado;
        }

        transaction.update(docRef, updates);
      });
    } catch (e) {
      throw ServerException('Error al validar reporte: $e');
    }
  }
}
