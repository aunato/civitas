import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../domain/entities/reporte_entity.dart';

/// Servicio de generación y exportación de informes oficiales en PDF
/// con diseño formal, membrete institucional y métricas operativas
/// para Carabineros de Chile, PDI y Dirigentes Vecinales.
class PdfReportService {
  PdfReportService._();

  static String _formatTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return 'Pánico SOS';
      case FirebaseConstants.tipoRoboVehiculo:
        return 'Robo Vehículo/Accesorios';
      case FirebaseConstants.tipoActividadSospechosa:
        return 'Actividad Sospechosa';
      case FirebaseConstants.tipoEmergenciaMedica:
        return 'Emergencia Médica';
      case FirebaseConstants.tipoAsalto:
        return 'Asalto / Intimidación';
      default:
        return tipo.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Construye el documento PDF con formato oficial de la República de Chile
  static Future<Uint8List> generatePdfBytes({
    required List<ReporteEntity> reportes,
    required String sectorNombre,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Métricas operativas consolidadas
    int sosCount = 0;
    int robosCount = 0;
    int sospechasCount = 0;
    int asaltosCount = 0;
    int emergenciasCount = 0;
    int validadosCount = 0;

    for (final r in reportes) {
      if (r.tipo == FirebaseConstants.tipoBotonPanico) sosCount++;
      if (r.tipo == FirebaseConstants.tipoRoboVehiculo) robosCount++;
      if (r.tipo == FirebaseConstants.tipoActividadSospechosa) sospechasCount++;
      if (r.tipo == FirebaseConstants.tipoAsalto) asaltosCount++;
      if (r.tipo == FirebaseConstants.tipoEmergenciaMedica) emergenciasCount++;
      if (r.isValidated) validadosCount++;
    }

    final totalIncidentes = reportes.length;
    final tasaVeracidad = totalIncidentes > 0
        ? ((validadosCount / totalIncidentes) * 100).toStringAsFixed(1)
        : '0.0';

    final primaryBlue = PdfColor.fromHex('#1E3A8A');
    final darkNavy = PdfColor.fromHex('#0F172A');
    final accentRed = PdfColor.fromHex('#DC2626');
    final lightGrey = PdfColor.fromHex('#F1F5F9');
    final borderGrey = PdfColor.fromHex('#CBD5E1');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPÚBLICA DE CHILE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: darkNavy,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.Text(
                      'PLATAFORMA CIVITAS • SEGURIDAD CIUDADANA',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    pw.Text(
                      'Macrozona Norte • Región de Tarapacá (Iquique - Alto Hospicio)',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: primaryBlue, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    color: lightGrey,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FOLIO OFICIAL: CIV-${now.year}${now.month.toString().padLeft(2, '0')}-${reportes.length}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: darkNavy,
                        ),
                      ),
                      pw.Text(
                        'Emisión: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: primaryBlue),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: borderGrey),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CIVITAS - Documento oficial generado bajo el amparo de la Ley N° 19.628 (Datos Anonimizados)',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Título del documento
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderGrey),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'INFORME OFICIAL DE INTELIGENCIA TERRITORIAL Y COPRODUCCIÓN DE SEGURIDAD',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: darkNavy,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Destinatarios Oficiales: Carabineros de Chile (Plan Cuadrante) • Policía de Investigaciones (PDI) • Unión Comunal de Juntas de Vecinos',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Sector Focalizado: $sectorNombre • Período: Últimos 7 Días de Registro Continuo',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Resumen de Métricas Operativas en Cajas
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricCard(
                title: 'Total Incidentes',
                value: '$totalIncidentes',
                subtitle: 'Alertas en sector',
                color: primaryBlue,
              ),
              _buildMetricCard(
                title: 'Alertas Validadas',
                value: '$validadosCount',
                subtitle: '>= 5 confirmaciones',
                color: PdfColor.fromHex('#059669'),
              ),
              _buildMetricCard(
                title: 'Pánico SOS',
                value: '$sosCount',
                subtitle: 'Prioridad máxima',
                color: accentRed,
              ),
              _buildMetricCard(
                title: 'Tasa Veracidad',
                value: '$tasaVeracidad%',
                subtitle: 'Mitigación cifra negra',
                color: darkNavy,
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // Desglose por Tipología
          pw.Text(
            'DISTRIBUCIÓN TIPOLÓGICA DE INCIDENTES',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: darkNavy,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: lightGrey),
                children: [
                  _tableCell('Categoría / Delito', isHeader: true),
                  _tableCell('Eventos', isHeader: true, align: pw.TextAlign.center),
                  _tableCell('% del Total', isHeader: true, align: pw.TextAlign.center),
                  _tableCell('Prioridad Operativa', isHeader: true),
                ],
              ),
              _tableRow('Botón de Pánico SOS', sosCount, totalIncidentes, 'Alta Inmediata (Plan Cuadrante)'),
              _tableRow('Robo de Vehículo / Accesorios', robosCount, totalIncidentes, 'Media / Patrullaje Focalizado'),
              _tableRow('Asalto o Intimidación', asaltosCount, totalIncidentes, 'Alta / Investigación Policial'),
              _tableRow('Actividad Sospechosa', sospechasCount, totalIncidentes, 'Preventiva / Vigilancia Vecinal'),
              _tableRow('Emergencia Médica Vecinal', emergenciasCount, totalIncidentes, 'Derivación SAMU / Red de Apoyo'),
            ],
          ),
          pw.SizedBox(height: 16),

          // Tabla Cronológica de Incidentes
          pw.Text(
            'REGISTRO CRONOLÓGICO Y GEORREFERENCIACIÓN DE SUCESOS',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: darkNavy,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(1.8),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(2.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: lightGrey),
                children: [
                  _tableCell('N°', isHeader: true, align: pw.TextAlign.center),
                  _tableCell('Fecha / Hora', isHeader: true),
                  _tableCell('Tipología', isHeader: true),
                  _tableCell('Coordenadas GPS', isHeader: true),
                  _tableCell('Validac.', isHeader: true, align: pw.TextAlign.center),
                  _tableCell('Estado', isHeader: true, align: pw.TextAlign.center),
                ],
              ),
              ...reportes.take(25).toList().asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final r = entry.value;
                final fecha =
                    '${r.timestamp.day.toString().padLeft(2, '0')}/${r.timestamp.month.toString().padLeft(2, '0')} ${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
                final coords = '${r.latitud.toStringAsFixed(4)}, ${r.longitud.toStringAsFixed(4)}';

                return pw.TableRow(
                  children: [
                    _tableCell('$idx', align: pw.TextAlign.center),
                    _tableCell(fecha),
                    _tableCell(_formatTipo(r.tipo)),
                    _tableCell(coords),
                    _tableCell('${r.contadorValidaciones}', align: pw.TextAlign.center),
                    _tableCell(r.isValidated ? 'VALIDADO' : 'ACTIVO',
                        align: pw.TextAlign.center,
                        color: r.isValidated ? PdfColor.fromHex('#059669') : PdfColors.black),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),

          // Bloque de Firmas y Timbres Institucionales
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 170, height: 1, color: darkNavy),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'DIRIGENCIA VECINAL',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkNavy),
                    ),
                    pw.Text(
                      'Presidente / Junta de Vecinos',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Sector: $sectorNombre',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 170, height: 1, color: darkNavy),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'CARABINEROS DE CHILE / PDI',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkNavy),
                    ),
                    pw.Text(
                      'Oficial Encargado del Plan Cuadrante',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Recepción de Evidencia Territorial',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required PdfColor color,
  }) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColor.fromHex('#F8FAFC'),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColor.fromHex('#0F172A') : PdfColors.black),
        ),
      ),
    );
  }

  static pw.TableRow _tableRow(String cat, int count, int total, String prio) {
    final pct = total > 0 ? ((count / total) * 100).toStringAsFixed(1) : '0.0';
    return pw.TableRow(
      children: [
        _tableCell(cat),
        _tableCell('$count', align: pw.TextAlign.center),
        _tableCell('$pct %', align: pw.TextAlign.center),
        _tableCell(prio),
      ],
    );
  }

  /// Despliega el diálogo interactivo para previsualizar o imprimir el reporte PDF
  static Future<void> previewPdf({
    required BuildContext context,
    required List<ReporteEntity> reportes,
    required String sectorNombre,
  }) async {
    final bytes = await generatePdfBytes(
      reportes: reportes,
      sectorNombre: sectorNombre,
    );

    await Printing.layoutPdf(
      name: 'CIVITAS_Informe_Oficial_${DateTime.now().millisecondsSinceEpoch}.pdf',
      onLayout: (format) async => bytes,
    );
  }

  /// Comparte o descarga el archivo PDF directamente en el dispositivo móvil
  static Future<void> exportAndSharePdf({
    required BuildContext context,
    required List<ReporteEntity> reportes,
    required String sectorNombre,
  }) async {
    final bytes = await generatePdfBytes(
      reportes: reportes,
      sectorNombre: sectorNombre,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'CIVITAS_Informe_Oficial_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
