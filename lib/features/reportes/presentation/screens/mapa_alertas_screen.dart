import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/entities/reporte_entity.dart';
import '../../domain/usecases/get_reportes_cercanos_usecase.dart';
import '../../domain/usecases/validar_reporte_usecase.dart';
import '../widgets/tarjeta_reporte.dart';

class MapaAlertasScreen extends StatefulWidget {
  final String currentUserId;
  final GetReportesCercanosUseCase getReportesUseCase;
  final ValidarReporteUseCase validarReporteUseCase;

  const MapaAlertasScreen({
    super.key,
    required this.currentUserId,
    required this.getReportesUseCase,
    required this.validarReporteUseCase,
  });

  @override
  State<MapaAlertasScreen> createState() => _MapaAlertasScreenState();
}

class _MapaAlertasScreenState extends State<MapaAlertasScreen> {
  final MapController _mapController = MapController();
  LatLng _initialPosition = const LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _centerUserLocation();
  }

  Future<void> _centerUserLocation() async {
    try {
      final position = await LocationService.instance.getCurrentLocation();
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _initialPosition = userLatLng;
        _isLoadingLocation = false;
      });

      _mapController.move(userLatLng, 16);
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  List<Marker> _buildMarkers(List<ReporteEntity> reportes) {
    return reportes.map((rep) {
      final isPanic = rep.isPanicAlert;
      final color = isPanic
          ? AppColors.panicRed
          : (rep.isValidated ? AppColors.warningOrange : const Color(0xFFFBC02D));

      return Marker(
        point: LatLng(rep.latitud, rep.longitud),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _mostrarDetalleReporte(rep),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: color, width: 2.5),
            ),
            padding: const EdgeInsets.all(5),
            child: Icon(
              isPanic ? Icons.emergency : Icons.warning_amber_rounded,
              color: color,
              size: 22,
            ),
          ),
        ),
      );
    }).toList();
  }

  void _mostrarDetalleReporte(ReporteEntity reporte) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TarjetaReporte(
              reporte: reporte,
              isOwner: reporte.autorRef == widget.currentUserId,
              onValidar: () async {
                await widget.validarReporteUseCase.call(
                  idReporte: reporte.idReporte,
                  validadorUid: widget.currentUserId,
                );
                if (mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Comunitario CIVITAS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerUserLocation,
            tooltip: 'Centrar en mi ubicación',
          ),
        ],
      ),
      body: StreamBuilder<List<ReporteEntity>>(
        stream: widget.getReportesUseCase.call(),
        builder: (context, snapshot) {
          final reportes = snapshot.data ?? [];
          final markers = _buildMarkers(reportes);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialPosition,
                  initialZoom: AppConstants.defaultZoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.civitas.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      // Marcador de posición del usuario
                      Marker(
                        point: _initialPosition,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                      ...markers,
                    ],
                  ),
                ],
              ),

              if (_isLoadingLocation)
                const Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Obteniendo ubicación GPS precisa...'),
                        ],
                      ),
                    ),
                  ),
                ),

              // Contador flotante de incidentes en vivo
              Positioned(
                bottom: 24,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${reportes.length} Alertas activas en la zona',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
