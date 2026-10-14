import '../entities/reporte_entity.dart';

abstract class ReportesRepository {
  /// Guarda un nuevo reporte capturando la ubicación GPS y tipo de incidente
  Future<String> guardarReporteConUbicacionActual({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    double? latitud,
    double? longitud,
  });

  /// Crear un nuevo incidente o reporte vecinal
  Future<void> crearReporte(ReporteEntity reporte);

  /// Disparo inmediato del Botón de Pánico (HU-02: < 3 segundos)
  Future<String> activarBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  });

  /// Stream en tiempo real de reportes activos para pintar en el mapa
  Stream<List<ReporteEntity>> getReportesActivosStream();

  /// Validar un reporte por parte de un vecino (+1 confirmación)
  Future<void> validarReporte({
    required String idReporte,
    required String validadorUid,
  });
}
