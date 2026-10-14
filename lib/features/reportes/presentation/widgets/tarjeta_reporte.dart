import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../domain/entities/reporte_entity.dart';

class TarjetaReporte extends StatelessWidget {
  final ReporteEntity reporte;
  final VoidCallback? onValidar;
  final bool isOwner;

  const TarjetaReporte({
    super.key,
    required this.reporte,
    this.onValidar,
    this.isOwner = false,
  });

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return AppColors.panicRed;
      case FirebaseConstants.tipoRoboVehiculo:
      case FirebaseConstants.tipoAsalto:
        return AppColors.warningOrange;
      case FirebaseConstants.tipoEmergenciaMedica:
        return Colors.purple;
      default:
        return AppColors.infoBlue;
    }
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return Icons.emergency;
      case FirebaseConstants.tipoRoboVehiculo:
        return Icons.directions_car;
      case FirebaseConstants.tipoEmergenciaMedica:
        return Icons.local_hospital;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _formatTipo(String tipo) {
    return tipo.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForTipo(reporte.tipo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_getIconForTipo(reporte.tipo), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTipo(reporte.tipo),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${reporte.timestamp.hour.toString().padLeft(2, '0')}:${reporte.timestamp.minute.toString().padLeft(2, '0')} - '
                        '${reporte.timestamp.day}/${reporte.timestamp.month}/${reporte.timestamp.year}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: reporte.isValidated ? AppColors.successGreen.withOpacity(0.15) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reporte.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: reporte.isValidated ? AppColors.successGreen : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${reporte.contadorValidaciones} confirmaciones',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (!isOwner && onValidar != null)
                  TextButton.icon(
                    onPressed: onValidar,
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                    label: const Text('Confirmar Alerta'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
