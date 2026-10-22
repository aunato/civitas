import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../domain/entities/reporte_entity.dart';

class ReporteSemanalScreen extends StatelessWidget {
  final List<ReporteEntity> reportes;
  final String sectorNombre;

  const ReporteSemanalScreen({
    super.key,
    required this.reportes,
    this.sectorNombre = 'Sector Comunitario',
  });

  String _formatTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return 'Pánico SOS';
      case FirebaseConstants.tipoRoboVehiculo:
        return 'Robo Vehicular / Accesorios';
      case FirebaseConstants.tipoActividadSospechosa:
        return 'Actividad Sospechosa';
      case FirebaseConstants.tipoEmergenciaMedica:
        return 'Emergencia Médica';
      case FirebaseConstants.tipoAsalto:
        return 'Asalto o Intimidación';
      default:
        return tipo.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _exportarReporte(BuildContext context, List<ReporteEntity> incidentesSemana) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    buffer.writeln('==============================================');
    buffer.writeln('CIVITAS - REPORTE CONSOLIDADO SEMANAL DE SEGURIDAD');
    buffer.writeln('Sector: $sectorNombre');
    buffer.writeln('Fecha de Emisión: ${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
    buffer.writeln('Total de Incidentes (Últimos 7 días): ${incidentesSemana.length}');
    buffer.writeln('==============================================\n');

    final mapaTipos = <String, int>{};
    int validados = 0;

    for (final r in incidentesSemana) {
      mapaTipos[r.tipo] = (mapaTipos[r.tipo] ?? 0) + 1;
      if (r.isValidated) validados++;
    }

    buffer.writeln('RESUMEN ESTADÍSTICO:');
    mapaTipos.forEach((tipo, count) {
      buffer.writeln('- ${_formatTipo(tipo)}: $count');
    });
    buffer.writeln('- Alertas Validadas Comunitariamente: $validados\n');

    buffer.writeln('DETALLE CRONOLÓGICO DE EVENTOS:');
    for (int i = 0; i < incidentesSemana.length; i++) {
      final r = incidentesSemana[i];
      final fechaStr = '${r.timestamp.day}/${r.timestamp.month} ${r.timestamp.hour}:${r.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln(
        '${i + 1}. [$fechaStr] ${_formatTipo(r.tipo)} - Confirmaciones: ${r.contadorValidaciones} (Coords: ${r.latitud.toStringAsFixed(4)}, ${r.longitud.toStringAsFixed(4)})',
      );
    }

    buffer.writeln('\nDocumento generado automáticamente por CIVITAS para juntas vecinales.');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.successGreen,
        content: Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Reporte consolidado copiado al portapapeles para exportación.'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final haceUnaSemana = now.subtract(const Duration(days: 7));

    final incidentesSemana = reportes.where((r) => r.timestamp.isAfter(haceUnaSemana)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    int sosCount = 0;
    int robosCount = 0;
    int sospechasCount = 0;
    int asaltosCount = 0;
    int validadosCount = 0;

    for (final r in incidentesSemana) {
      if (r.tipo == FirebaseConstants.tipoBotonPanico) sosCount++;
      if (r.tipo == FirebaseConstants.tipoRoboVehiculo) robosCount++;
      if (r.tipo == FirebaseConstants.tipoActividadSospechosa) sospechasCount++;
      if (r.tipo == FirebaseConstants.tipoAsalto) asaltosCount++;
      if (r.isValidated) validadosCount++;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte Semanal Consolidado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Exportar Reporte',
            onPressed: () => _exportarReporte(context, incidentesSemana),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de Rol
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium, color: Color(0xFFD97706), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Módulo Especial: Presidente Junta Vecinal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Información consolidada de los últimos 7 días para coordinación con Carabineros y Seguridad Municipal.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Tarjetas de Métricas Rápidas
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Semana',
                    value: '${incidentesSemana.length}',
                    icon: Icons.analytics_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pánico SOS',
                    value: '$sosCount',
                    icon: Icons.emergency,
                    color: AppColors.panicRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Validados',
                    value: '$validadosCount',
                    icon: Icons.verified,
                    color: AppColors.successGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Robos / Hurtos',
                    value: '$robosCount',
                    icon: Icons.directions_car,
                    color: AppColors.warningOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Asaltos',
                    value: '$asaltosCount',
                    icon: Icons.warning_rounded,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Sospecha',
                    value: '$sospechasCount',
                    icon: Icons.visibility,
                    color: const Color(0xFFFBC02D),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botón de exportación rápida
            ElevatedButton.icon(
              onPressed: () => _exportarReporte(context, incidentesSemana),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Exportar Resumen Consolidado (Copiar)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Detalle de Eventos Registrados en la Semana',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),

            if (incidentesSemana.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'No se registraron incidentes en los últimos 7 días.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: incidentesSemana.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rep = incidentesSemana[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: rep.tipo == FirebaseConstants.tipoBotonPanico
                            ? AppColors.panicRed.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.15),
                        child: Icon(
                          rep.tipo == FirebaseConstants.tipoBotonPanico
                              ? Icons.emergency
                              : Icons.warning_rounded,
                          color: rep.tipo == FirebaseConstants.tipoBotonPanico
                              ? AppColors.panicRed
                              : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        _formatTipo(rep.tipo),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${rep.timestamp.day}/${rep.timestamp.month} ${rep.timestamp.hour}:${rep.timestamp.minute.toString().padLeft(2, '0')} • ${rep.contadorValidaciones} validaciones',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: rep.isValidated
                              ? AppColors.successGreen.withOpacity(0.12)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          rep.isValidated ? 'VALIDADO' : 'ACTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: rep.isValidated ? AppColors.successGreen : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
