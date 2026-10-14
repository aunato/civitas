import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/usecases/crear_reporte_usecase.dart';

class BotonPanico extends StatefulWidget {
  final String userUid;
  final CrearReporteUseCase crearReporteUseCase;
  final VoidCallback? onAlertaEnviada;

  const BotonPanico({
    super.key,
    required this.userUid,
    required this.crearReporteUseCase,
    this.onAlertaEnviada,
  });

  @override
  State<BotonPanico> createState() => _BotonPanicoState();
}

class _BotonPanicoState extends State<BotonPanico> {
  bool _isTriggering = false;

  Future<void> _handlePanicPress() async {
    if (_isTriggering) return;

    setState(() => _isTriggering = true);

    try {
      // HU-03: Detección automática de ubicación GPS al reportar
      final position = await LocationService.getCurrentLocation();

      // HU-02: Envío inmediato en menos de 3 segundos
      await widget.crearReporteUseCase.dispararBotonPanico(
        autorUid: widget.userUid,
        latitud: position.latitude,
        longitud: position.longitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.panicRed,
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¡ALERTA DE PÁNICO ENVIADA A LA COMUNIDAD!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      widget.onAlertaEnviada?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('Error al emitir alerta de pánico: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTriggering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isTriggering ? null : _handlePanicPress,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.panicRed,
              boxShadow: [
                BoxShadow(
                  color: AppColors.panicRed.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: _isTriggering
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_active,
                          size: 56,
                          color: Colors.white,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'PÁNICO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Presiona para SOS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Alerta a los vecinos en un radio de 500m',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
