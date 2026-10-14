import 'dart:async';
import 'package:civitas/core/utils/geo_utils.dart';
import 'package:civitas/features/reportes/domain/entities/reporte_entity.dart';
import 'package:civitas/features/reportes/domain/repositories/reportes_repository.dart';

class MockReportesRepository implements ReportesRepository {
  final StreamController<List<ReporteEntity>> _streamController =
      StreamController<List<ReporteEntity>>.broadcast();

  final List<ReporteEntity> _reportes = [];
  int panicCalls = 0;
  int guardarCalls = 0;

  void emitReportes(List<ReporteEntity> list) {
    _reportes.clear();
    _reportes.addAll(list);
    _streamController.add(List.unmodifiable(_reportes));
  }

  @override
  Future<String> guardarReporteConUbicacionActual({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    double? latitud,
    double? longitud,
  }) async {
    guardarCalls++;
    final lat = latitud ?? -23.6509;
    final lng = longitud ?? -70.3975;
    final geohash = GeoUtils.encodeGeohash(latitude: lat, longitude: lng);

    final reporte = ReporteEntity(
      idReporte: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      autorRef: autorUid,
      tipo: tipoIncidente,
      latitud: lat,
      longitud: lng,
      geohash: geohash,
      estado: 'ACTIVO',
      contadorValidaciones: 0,
      timestamp: DateTime.now(),
      evidenciaUrl: evidenciaUrl,
    );

    _reportes.add(reporte);
    _streamController.add(List.unmodifiable(_reportes));
    return reporte.idReporte;
  }

  @override
  Future<void> crearReporte(ReporteEntity reporte) async {
    _reportes.add(reporte);
    _streamController.add(List.unmodifiable(_reportes));
  }

  @override
  Future<String> activarBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  }) async {
    panicCalls++;
    final panic = ReporteEntity(
      idReporte: 'panic_${DateTime.now().millisecondsSinceEpoch}',
      autorRef: autorUid,
      tipo: 'boton_panico',
      latitud: latitud,
      longitud: longitud,
      geohash: '',
      estado: 'ACTIVO',
      contadorValidaciones: 1,
      timestamp: DateTime.now(),
    );
    _reportes.add(panic);
    _streamController.add(List.unmodifiable(_reportes));
    return panic.idReporte;
  }

  @override
  Stream<List<ReporteEntity>> getReportesActivosStream() {
    return _streamController.stream;
  }

  @override
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  }) async {
    final idx = _reportes.indexWhere((r) => r.idReporte == idReporte);
    if (idx != -1) {
      final rep = _reportes[idx];
      final newCount = rep.contadorValidaciones + 1;
      _reportes[idx] = ReporteEntity(
        idReporte: rep.idReporte,
        autorRef: rep.autorRef,
        tipo: rep.tipo,
        latitud: rep.latitud,
        longitud: rep.longitud,
        geohash: rep.geohash,
        estado: newCount >= 5 ? 'VALIDADO' : rep.estado,
        contadorValidaciones: newCount,
        timestamp: rep.timestamp,
      );
      _streamController.add(List.unmodifiable(_reportes));
    }
  }

  void dispose() {
    _streamController.close();
  }
}
