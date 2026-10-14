import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/reporte_entity.dart';
import '../../domain/repositories/reportes_repository.dart';
import '../datasources/reportes_remote_datasource.dart';
import '../models/reporte_model.dart';

class ReportesRepositoryImpl implements ReportesRepository {
  final ReportesRemoteDataSource remoteDataSource;

  ReportesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String> guardarReporteConUbicacionActual({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    double? latitud,
    double? longitud,
  }) async {
    GeoPoint? geo;
    if (latitud != null && longitud != null) {
      geo = GeoPoint(latitud, longitud);
    }

    return await remoteDataSource.guardarReporteConUbicacionActual(
      autorUid: autorUid,
      tipoIncidente: tipoIncidente,
      evidenciaUrl: evidenciaUrl,
      coordenadas: geo,
    );
  }

  @override
  Future<void> crearReporte(ReporteEntity reporte) async {
    final model = ReporteModel(
      id_reporte: reporte.idReporte,
      autor_ref: reporte.autorRef,
      tipo: reporte.tipo,
      coordenadas: GeoPoint(reporte.latitud, reporte.longitud),
      geohash: reporte.geohash,
      estado: reporte.estado,
      contador_validaciones: reporte.contadorValidaciones,
      timestamp: reporte.timestamp,
      evidencia_url: reporte.evidenciaUrl,
    );
    await remoteDataSource.crearReporte(model);
  }

  @override
  Future<String> activarBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  }) async {
    return await remoteDataSource.activarBotonPanico(
      autorUid: autorUid,
      latitud: latitud,
      longitud: longitud,
    );
  }

  @override
  Stream<List<ReporteEntity>> getReportesActivosStream() {
    return remoteDataSource.getReportesActivosStream();
  }

  @override
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  }) async {
    await remoteDataSource.validarReporte(
      idReporte: idReporte,
      validadorUid: validadorUid,
    );
  }
}
