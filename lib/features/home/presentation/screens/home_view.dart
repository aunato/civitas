import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/presentation/screens/login_view.dart';
import '../../../reportes/data/datasources/reportes_remote_datasource.dart';
import '../../../reportes/data/repositories/reportes_repository_impl.dart';
import '../../../reportes/domain/entities/reporte_entity.dart';
import '../../../reportes/domain/usecases/crear_reporte_usecase.dart';
import '../../../reportes/domain/usecases/get_reportes_cercanos_usecase.dart';
import '../../../reportes/domain/usecases/validar_reporte_usecase.dart';
import '../../../reportes/presentation/screens/crear_reporte_screen.dart';
import '../../../reportes/presentation/widgets/boton_panico.dart';
import '../../../reportes/presentation/widgets/tarjeta_reporte.dart';

class HomeView extends StatefulWidget {
  final UserEntity currentUser;
  final ILocationService? locationService;
  final GetReportesCercanosUseCase? getReportesUseCase;
  final CrearReporteUseCase? crearReporteUseCase;
  final ValidarReporteUseCase? validarReporteUseCase;

  const HomeView({
    super.key,
    required this.currentUser,
    this.locationService,
    this.getReportesUseCase,
    this.crearReporteUseCase,
    this.validarReporteUseCase,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  GoogleMapController? _mapController;
  late final ILocationService _locationService;
  late final GetReportesCercanosUseCase _getReportesUseCase;
  late final CrearReporteUseCase _crearReporteUseCase;
  late final ValidarReporteUseCase _validarReporteUseCase;

  bool _isAcquiringLocation = false;
  LatLng? _currentLatLng;
  String? _locationStatusMessage;

  // Posición inicial por defecto antes de obtener GPS
  static const LatLng _defaultLocation = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService.instance;

    final reportesRemote = ReportesRemoteDataSourceImpl();
    final reportesRepo = ReportesRepositoryImpl(remoteDataSource: reportesRemote);

    _getReportesUseCase = widget.getReportesUseCase ?? GetReportesCercanosUseCase(reportesRepo);
    _crearReporteUseCase = widget.crearReporteUseCase ?? CrearReporteUseCase(reportesRepo);
    _validarReporteUseCase = widget.validarReporteUseCase ?? ValidarReporteUseCase(reportesRepo);
  }

  /// Recentra el mapa automáticamente en la posición del usuario usando el LocationService
  Future<void> _recenterOnUser({bool isInitial = false}) async {
    if (_isAcquiringLocation) return;

    setState(() {
      _isAcquiringLocation = true;
      _locationStatusMessage = 'Obteniendo señal GPS...';
    });

    try {
      // 1. Solicita permisos de ubicación en tiempo real
      await _locationService.handleLocationPermission();

      // 2. Obtiene coordenadas (Latitude, Longitude)
      final latLng = await _locationService.getCurrentLatLng();

      if (!mounted) return;

      setState(() {
        _currentLatLng = latLng;
        _isAcquiringLocation = false;
        _locationStatusMessage = null;
      });

      // 3. Anima la cámara de GoogleMap al punto del usuario
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: latLng,
              zoom: 16.5,
              tilt: 20.0,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAcquiringLocation = false;
        _locationStatusMessage = e.toString().replaceAll('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.panicRed,
          content: Text(_locationStatusMessage ?? 'No se pudo obtener la ubicación GPS.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Recentrado automático en la posición del usuario al cargar el mapa
    _recenterOnUser(isInitial: true);
  }

  double _getHueForTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return BitmapDescriptor.hueRed;
      case FirebaseConstants.tipoRoboVehiculo:
        return BitmapDescriptor.hueOrange;
      case FirebaseConstants.tipoActividadSospechosa:
        return BitmapDescriptor.hueYellow;
      case FirebaseConstants.tipoEmergenciaMedica:
        return BitmapDescriptor.hueViolet;
      case FirebaseConstants.tipoAsalto:
        return BitmapDescriptor.hueRose;
      default:
        return BitmapDescriptor.hueCyan;
    }
  }

  Set<Marker> _buildIncidentMarkers(List<ReporteEntity> reportes) {
    return reportes.map((rep) {
      final hue = _getHueForTipo(rep.tipo);

      return Marker(
        markerId: MarkerId(rep.idReporte),
        position: LatLng(rep.latitud, rep.longitud),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: rep.tipo.replaceAll('_', ' ').toUpperCase(),
          snippet: '${rep.contadorValidaciones} validaciones • ${rep.estado}',
          onTap: () => _showIncidentBottomSheet(rep),
        ),
      );
    }).toSet();
  }

  void _showIncidentBottomSheet(ReporteEntity reporte) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            TarjetaReporte(
              reporte: reporte,
              isOwner: reporte.autorRef == widget.currentUser.uid,
              onValidar: () async {
                await _validarReporteUseCase.call(
                  idReporte: reporte.idReporte,
                  validadorUid: widget.currentUser.uid,
                );
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Desea salir de CIVITAS y desconectar su cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.panicRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authRepo = AuthRepositoryImpl(remoteDataSource: AuthRemoteDataSourceImpl());
      await authRepo.signOut();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ReporteEntity>>(
        stream: _getReportesUseCase.call(),
        builder: (context, snapshot) {
          final reportes = snapshot.data ?? [];
          final markers = _buildIncidentMarkers(reportes);

          return Stack(
            children: [
              // 1. GoogleMap ocupando el 100% de la pantalla (Full Screen)
              Positioned.fill(
                child: GoogleMap(
                  key: const Key('home_google_map'),
                  initialCameraPosition: const CameraPosition(
                    target: _defaultLocation,
                    zoom: AppConstants.defaultZoom,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // Usamos botón flotante personalizado
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  markers: markers,
                  onMapCreated: _onMapCreated,
                ),
              ),

              // 2. Barra Superior Flotante: Identidad Ciudadana y Salir
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 18,
                          child: Icon(Icons.shield, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.currentUser.email,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${widget.currentUser.rol.toUpperCase()} • ',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${widget.currentUser.reputacion} pts',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.currentUser.reputacion >= 70
                                          ? AppColors.successGreen
                                          : AppColors.warningOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                          onPressed: _handleSignOut,
                          tooltip: 'Cerrar Sesión',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Indicador de alerta o adquisición de ubicación
              if (_isAcquiringLocation)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 32,
                  right: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sincronizando ubicación GPS...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Botón Flotante para Recentrar en la posición del Usuario (Geolocator)
              Positioned(
                right: 16,
                bottom: 180,
                child: FloatingActionButton(
                  key: const Key('recenter_gps_button'),
                  heroTag: 'btn_recenter',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                  shape: const CircleBorder(),
                  onPressed: () => _recenterOnUser(),
                  child: _isAcquiringLocation
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : const Icon(Icons.my_location, size: 26),
                ),
              ),

              // 5. Panel Inferior Flotante: Botón de Pánico y Crear Reporte
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chip de alertas activas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.panicRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${reportes.length} Incidentes en el perímetro',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Fila de acciones principales
                    Row(
                      children: [
                        // Botón de Pánico SOS
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            key: const Key('home_panic_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.panicRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.emergency, size: 28),
                            label: const Text(
                              'PÁNICO SOS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            onPressed: () async {
                              try {
                                final latLng = _currentLatLng ??
                                    await _locationService.getCurrentLatLng();
                                await _crearReporteUseCase.dispararBotonPanico(
                                  autorUid: widget.currentUser.uid,
                                  latitud: latLng.latitude,
                                  longitud: latLng.longitude,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.panicRed,
                                    content: Text('¡ALERTA DE PÁNICO ENVIADA A LA COMUNIDAD!'),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red.shade900,
                                    content: Text('Error al emitir alerta SOS: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón Reporte detallado
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            key: const Key('home_report_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.add_alert, size: 20),
                            label: const Text(
                              'Reportar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CrearReporteScreen(
                                    currentUserId: widget.currentUser.uid,
                                    crearReporteUseCase: _crearReporteUseCase,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
