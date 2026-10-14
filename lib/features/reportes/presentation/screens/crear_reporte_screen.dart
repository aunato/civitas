import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/reporte_entity.dart';
import '../../domain/usecases/crear_reporte_usecase.dart';

class CrearReporteScreen extends StatefulWidget {
  final String currentUserId;
  final CrearReporteUseCase crearReporteUseCase;

  const CrearReporteScreen({
    super.key,
    required this.currentUserId,
    required this.crearReporteUseCase,
  });

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  String _selectedTipo = FirebaseConstants.tipoActividadSospechosa;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _tiposIncidentes = [
    {
      'id': FirebaseConstants.tipoActividadSospechosa,
      'label': 'Actividad Sospechosa',
      'icon': Icons.remove_red_eye_outlined,
    },
    {
      'id': FirebaseConstants.tipoRoboVehiculo,
      'label': 'Robo de Vehículo / Accesorios',
      'icon': Icons.directions_car_outlined,
    },
    {
      'id': FirebaseConstants.tipoAsalto,
      'label': 'Asalto o Intimidación',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': FirebaseConstants.tipoEmergenciaMedica,
      'label': 'Emergencia Médica Vecinal',
      'icon': Icons.local_hospital_outlined,
    },
  ];

  Future<void> _enviarReporte() async {
    setState(() => _isLoading = true);

    try {
      // Guarda capturando automáticamente la ubicación actual GPS y el tipo de incidente
      await widget.crearReporteUseCase.guardarConUbicacion(
        autorUid: widget.currentUserId,
        tipoIncidente: _selectedTipo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Text('Reporte emitido con éxito a la red comunitaria.'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.panicRed,
          content: Text('Error al enviar reporte: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte Ciudadano'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seleccione el tipo de situación:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _tiposIncidentes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _tiposIncidentes[index];
                  final isSelected = _selectedTipo == item['id'];

                  return InkWell(
                    onTap: () {
                      setState(() => _selectedTipo = item['id'] as String);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 28,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Text(
              'Su ubicación actual será adjuntada automáticamente al reporte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _enviarReporte,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Publicar Alerta Vecinal'),
            ),
          ],
        ),
      ),
    );
  }
}
