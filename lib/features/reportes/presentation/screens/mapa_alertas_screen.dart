import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
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
      final position = await LocationService.getCurrentLocation();
      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _initialPosition = userLatLng;
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 16),
        ),
      );
    } catch (_) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Set<Marker> _buildMarkers(List<ReporteEntity> reportes) {
    return reportes.map((rep) {
      final isPanic = rep.isPanicAlert;
      final hue = isPanic
          ? BitmapDescriptor.hueRed
          : (rep.isValidated ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueYellow);

      return Marker(
        markerId: MarkerId(rep.idReporte),
        position: LatLng(rep.latitud, rep.longitud),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: rep.tipo.replaceAll('_', ' ').toUpperCase(),
          snippet: 'Confirmaciones: ${rep.contadorValidaciones} | Estado: ${rep.estado}',
          onTap: () => _mostrarDetalleReporte(rep),
        ),
      );
    }).toSet();
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
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialPosition,
                  zoom: AppConstants.defaultZoom,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: markers,
                onMapCreated: (controller) => _mapController = controller,
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
