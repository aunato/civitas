import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../domain/entities/reporte_entity.dart';

class TarjetaReporte extends StatefulWidget {
  final ReporteEntity reporte;
  final Future<void> Function()? onValidar;
  final bool isOwner;
  final String? currentUserId;

  const TarjetaReporte({
    super.key,
    required this.reporte,
    this.onValidar,
    this.isOwner = false,
    this.currentUserId,
  });

  @override
  State<TarjetaReporte> createState() => _TarjetaReporteState();
}

class _TarjetaReporteState extends State<TarjetaReporte> {
  bool _isValidating = false;
  late int _localCount;
  late bool _hasConfirmedLocally;

  @override
  void initState() {
    super.initState();
    _localCount = widget.reporte.contadorValidaciones;
    _hasConfirmedLocally = widget.currentUserId != null &&
        widget.reporte.isConfirmedBy(widget.currentUserId!);
  }

  @override
  void didUpdateWidget(TarjetaReporte oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reporte.contadorValidaciones != oldWidget.reporte.contadorValidaciones) {
      _localCount = widget.reporte.contadorValidaciones;
    }
    if (widget.currentUserId != null &&
        widget.reporte.isConfirmedBy(widget.currentUserId!)) {
      _hasConfirmedLocally = true;
    }
  }

  Future<void> _handleConfirmar() async {
    if (_isValidating || _hasConfirmedLocally) return;

    setState(() {
      _isValidating = true;
      _localCount += 1;
      _hasConfirmedLocally = true;
    });

    try {
      await widget.onValidar?.call();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

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
    final color = _getColorForTipo(widget.reporte.tipo);
    final isValidated = widget.reporte.isValidated || _localCount >= 5;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_getIconForTipo(widget.reporte.tipo), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTipo(widget.reporte.tipo),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${widget.reporte.timestamp.hour.toString().padLeft(2, '0')}:${widget.reporte.timestamp.minute.toString().padLeft(2, '0')} - '
                        '${widget.reporte.timestamp.day}/${widget.reporte.timestamp.month}/${widget.reporte.timestamp.year}',
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
                    color: isValidated ? AppColors.successGreen.withOpacity(0.15) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isValidated ? 'VALIDADO' : widget.reporte.estado,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isValidated ? AppColors.successGreen : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 20, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$_localCount confirmaciones',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!widget.isOwner)
                  _hasConfirmedLocally
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppColors.successGreen),
                              SizedBox(width: 4),
                              Text(
                                'Confirmada ✓',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _isValidating ? null : _handleConfirmar,
                          icon: _isValidating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Confirmar Alerta'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
