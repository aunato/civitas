import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/core/constants/firebase_constants.dart';
import 'package:civitas/features/reportes/data/services/pdf_report_service.dart';
import 'package:civitas/features/reportes/domain/entities/reporte_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfReportService - Generación de Informes Oficiales en PDF', () {
    test('1. Genera un documento PDF binario válido con cabecera estándar (%PDF)', () async {
      final now = DateTime.now();
      final reportesPrueba = [
        ReporteEntity(
          idReporte: 'rep_pdf_1',
          autorRef: 'vecino_test_1',
          tipo: FirebaseConstants.tipoBotonPanico,
          latitud: -20.2167,
          longitud: -70.1417,
          geohash: '66jc5q',
          estado: FirebaseConstants.estadoValidado,
          contadorValidaciones: 5,
          timestamp: now,
        ),
        ReporteEntity(
          idReporte: 'rep_pdf_2',
          autorRef: 'vecino_test_2',
          tipo: FirebaseConstants.tipoRoboVehiculo,
          latitud: -20.2180,
          longitud: -70.1430,
          geohash: '66jc5r',
          estado: FirebaseConstants.estadoActivo,
          contadorValidaciones: 2,
          timestamp: now.subtract(const Duration(hours: 2)),
        ),
      ];

      final pdfBytes = await PdfReportService.generatePdfBytes(
        reportes: reportesPrueba,
        sectorNombre: 'Junta de Vecinos Santa Rosa - Iquique',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Los archivos PDF siempre inician con la firma mágica '%PDF' (ASCII 0x25, 0x50, 0x44, 0x46)
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('2. Maneja listas vacías de incidentes sin fallas', () async {
      final pdfBytes = await PdfReportService.generatePdfBytes(
        reportes: const [],
        sectorNombre: 'Sector Comunitario Tarapacá',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });
  });
}
