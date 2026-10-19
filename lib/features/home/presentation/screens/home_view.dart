import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  late final ILocationService _locationService;
  late final GetReportesCercanosUseCase _getReportesUseCase;
  late final CrearReporteUseCase _crearReporteUseCase;
  late final ValidarReporteUseCase _validarReporteUseCase;

  bool _isAcquiringLocation = false;
  bool _hasLocationPermission = false;
  LatLng? _currentLatLng;
  String? _locationStatusMessage;

  // Posición inicial por defecto antes de obtener GPS
  static const LatLng _defaultLocation = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );

  late final Stream<List<ReporteEntity>> _reportesStream;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService.instance;

    if (widget.getReportesUseCase != null &&
        widget.crearReporteUseCase != null &&
        widget.validarReporteUseCase != null) {
      _getReportesUseCase = widget.getReportesUseCase!;
      _crearReporteUseCase = widget.crearReporteUseCase!;
      _validarReporteUseCase = widget.validarReporteUseCase!;
    } else {
      final reportesRemote = ReportesRemoteDataSourceImpl();
      final reportesRepo = ReportesRepositoryImpl(remoteDataSource: reportesRemote);

      _getReportesUseCase = widget.getReportesUseCase ?? GetReportesCercanosUseCase(reportesRepo);
      _crearReporteUseCase = widget.crearReporteUseCase ?? CrearReporteUseCase(reportesRepo);
      _validarReporteUseCase = widget.validarReporteUseCase ?? ValidarReporteUseCase(reportesRepo);
    }
    _reportesStream = _getReportesUseCase.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recenterOnUser(isInitial: true);
    });
  }

  void _showMapInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.public_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Cartografía Comunitaria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OpenStreetMap (OSM) Integrado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
              ),
              SizedBox(height: 8),
              Text(
                'CIVITAS utiliza OpenStreetMap para la visualización territorial comunitaria en tiempo real. Esto permite una cartografía 100% abierta, gratuita, sin bloqueos de facturación y con disponibilidad permanente para la comunidad.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                'Componentes en Pantalla:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 6),
              Text(
                '• Círculo azul perimetral: Radio de 500m para alertas de seguridad vecinal.\n'
                '• Marcadores de colores: Incidentes categorizados y reportes comunitarios.\n'
                '• Punto azul: Tu ubicación satelital GPS en tiempo real.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
        _hasLocationPermission = true;
        _currentLatLng = latLng;
        _isAcquiringLocation = false;
        _locationStatusMessage = null;
      });

      // 3. Mueve la cámara de OpenStreetMap a la posición del usuario
      _mapController.move(latLng, 16.5);
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

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return AppColors.panicRed;
      case FirebaseConstants.tipoRoboVehiculo:
        return AppColors.warningOrange;
      case FirebaseConstants.tipoActividadSospechosa:
        return const Color(0xFFFBC02D);
      case FirebaseConstants.tipoEmergenciaMedica:
        return const Color(0xFF8E24AA);
      case FirebaseConstants.tipoAsalto:
        return const Color(0xFFD81B60);
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case FirebaseConstants.tipoBotonPanico:
        return Icons.emergency;
      case FirebaseConstants.tipoRoboVehiculo:
        return Icons.directions_car;
      case FirebaseConstants.tipoActividadSospechosa:
        return Icons.visibility;
      case FirebaseConstants.tipoEmergenciaMedica:
        return Icons.medical_services;
      case FirebaseConstants.tipoAsalto:
        return Icons.warning_rounded;
      default:
        return Icons.location_on;
    }
  }

  List<Marker> _buildIncidentMarkers(List<ReporteEntity> reportes) {
    return reportes.map((rep) {
      final color = _getColorForTipo(rep.tipo);
      final icon = _getIconForTipo(rep.tipo);

      return Marker(
        key: Key('marker_${rep.idReporte}'),
        point: LatLng(rep.latitud, rep.longitud),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showIncidentBottomSheet(rep),
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
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );
    }).toList();
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
        stream: _reportesStream,
        builder: (context, snapshot) {
          final reportes = snapshot.data ?? [];
          final markers = _buildIncidentMarkers(reportes);

          return Stack(
            children: [
              // 1. OpenStreetMap (OSM) a pantalla completa
              Positioned.fill(
                child: FlutterMap(
                  key: const Key('home_osm_map'),
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _defaultLocation,
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
                    // Perímetro de seguridad comunitario de 500m
                    if (_currentLatLng != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _currentLatLng!,
                            radius: 500,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withOpacity(0.12),
                            borderColor: AppColors.primary.withOpacity(0.6),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    // Marcador de posición GPS del usuario
                    if (_currentLatLng != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLatLng!,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Marcadores de incidentes reportados
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
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
                          icon: const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                          onPressed: _showMapInfo,
                          tooltip: 'Cartografía Comunitaria',
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

              // 3. Indicador de geolocalización GPS activa
              Positioned(
                top: MediaQuery.of(context).padding.top + 78,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAcquiringLocation ? Icons.satellite_alt_outlined : Icons.gps_fixed_rounded,
                        size: 20,
                        color: _isAcquiringLocation ? AppColors.warningOrange : AppColors.successGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isAcquiringLocation
                              ? 'Sincronizando señal GPS con satélites...'
                              : (_currentLatLng != null
                                  ? 'GPS Activo: ${_currentLatLng!.latitude.toStringAsFixed(4)}, ${_currentLatLng!.longitude.toStringAsFixed(4)} • Radio 500m'
                                  : 'Ubicación activa (Antofagasta, Chile)'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
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
