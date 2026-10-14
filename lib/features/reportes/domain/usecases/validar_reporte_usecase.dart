import '../repositories/reportes_repository.dart';

class ValidarReporteUseCase {
  final ReportesRepository repository;

  ValidarReporteUseCase(this.repository);

  Future<void> call({required String idReporte, required String validadorUid}) {
    return repository.validarReporte(
      idReporte: idReporte,
      validadorUid: validadorUid,
    );
  }
}
