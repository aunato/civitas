import '../entities/reporte_entity.dart';
import '../repositories/reportes_repository.dart';

class GetReportesCercanosUseCase {
  final ReportesRepository repository;

  GetReportesCercanosUseCase(this.repository);

  Stream<List<ReporteEntity>> call() {
    return repository.getReportesActivosStream();
  }
}
