import '../entities/reporte_entity.dart';
import '../repositories/reportes_repository.dart';

class CrearReporteUseCase {
  final ReportesRepository repository;

  CrearReporteUseCase(this.repository);

  /// Guarda el reporte capturando la ubicación actual y tipo de incidente seleccionado
  Future<String> guardarConUbicacion({
    required String autorUid,
    required String tipoIncidente,
    String? evidenciaUrl,
    double? latitud,
    double? longitud,
  }) {
    return repository.guardarReporteConUbicacionActual(
      autorUid: autorUid,
      tipoIncidente: tipoIncidente,
      evidenciaUrl: evidenciaUrl,
      latitud: latitud,
      longitud: longitud,
    );
  }

  Future<void> call(ReporteEntity reporte) {
    return repository.crearReporte(reporte);
  }

  Future<String> dispararBotonPanico({
    required String autorUid,
    required double latitud,
    required double longitud,
  }) {
    return repository.activarBotonPanico(
      autorUid: autorUid,
      latitud: latitud,
      longitud: longitud,
    );
  }
}
