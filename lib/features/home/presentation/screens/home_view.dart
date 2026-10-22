import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/presentation/screens/login_view.dart';
import '../../../auth/presentation/screens/perfil_usuario_screen.dart';
import '../../../reportes/data/datasources/reportes_remote_datasource.dart';
import '../../../reportes/data/repositories/reportes_repository_impl.dart';
import '../../../reportes/domain/entities/reporte_entity.dart';
import '../../../reportes/domain/usecases/crear_reporte_usecase.dart';
import '../../../reportes/domain/usecases/get_reportes_cercanos_usecase.dart';
import '../../../reportes/domain/usecases/validar_reporte_usecase.dart';
import '../../../reportes/presentation/screens/crear_reporte_screen.dart';
import '../../../reportes/presentation/screens/reporte_semanal_screen.dart';
import '../../../reportes/presentation/widgets/tarjeta_reporte.dart';

class HomeView extends StatefulWidget {
  final UserEntity currentUser;
  final ILocationService? locationService;
  final GetReportesCercanosUseCase? getReportesUseCase;
  final CrearReporteUseCase? crearReporteUseCase;
  final ValidarReporteUseCase? validarReporteUseCase;
  final TileProvider? tileProvider;

  const HomeView({
    super.key,
    required this.currentUser,
    this.locationService,
    this.getReportesUseCase,
    this.crearReporteUseCase,
    this.validarReporteUseCase,
    this.tileProvider,
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

  late UserEntity _currentUser;
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
  StreamSubscription<List<ReporteEntity>>? _reportesSubscription;
  StreamSubscription? _fcmSubscription;
  final Set<String> _knownReportIds = {};
  bool _isInitialReportLoad = true;

  // Contador dinámico temporal del perímetro
  bool _showPerimeterCount = false;
  Timer? _perimeterCountTimer;
  int _perimeterCount = 0;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
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
    _reportesSubscription = _reportesStream.listen((reportes) {
      if (!mounted) return;
      _checkNewProximityAlerts(reportes);
    });

    // Escuchar alertas push recibidas en primer plano (FCM Foreground)
    _fcmSubscription = NotificationService.onForegroundMessage.listen((RemoteMessage message) {
      if (!mounted) return;
      final title = message.notification?.title ?? '🚨 Alerta Comunitaria';
      final body = message.notification?.body ?? 'Nuevo incidente en tu sector.';
      final latStr = message.data['latitud'];
      final lngStr = message.data['longitud'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.panicRed,
          duration: const Duration(seconds: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12)),
            ],
          ),
          action: (latStr != null && lngStr != null)
              ? SnackBarAction(
                  label: 'VER EN MAPA',
                  textColor: Colors.white,
                  onPressed: () {
                    final lat = double.tryParse(latStr);
                    final lng = double.tryParse(lngStr);
                    if (lat != null && lng != null) {
                      _mapController.move(LatLng(lat, lng), 17.5);
                    }
                  },
                )
              : null,
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recenterOnUser(isInitial: true);
    });
  }

  @override
  void dispose() {
    _reportesSubscription?.cancel();
    _fcmSubscription?.cancel();
    _perimeterCountTimer?.cancel();
    super.dispose();
  }

  void _activarBadgePerimetroTemporal(int totalIncidentes) {
    if (!mounted) return;
    setState(() {
      _showPerimeterCount = true;
      _perimeterCount = totalIncidentes;
    });
    _perimeterCountTimer?.cancel();
    _perimeterCountTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() => _showPerimeterCount = false);
      }
    });
  }

  void _checkNewProximityAlerts(List<ReporteEntity> reportes) {
    final center = _currentLatLng ?? _defaultLocation;
    final alertasEnZona = reportes.where((rep) {
      return LocationService.isWithinAlertRadius(
        userLat: center.latitude,
        userLng: center.longitude,
        alertLat: rep.latitud,
        alertLng: rep.longitud,
        radiusMeters: 500,
      );
    }).toList();

    if (_isInitialReportLoad) {
      for (final r in reportes) {
        _knownReportIds.add(r.idReporte);
      }
      _isInitialReportLoad = false;
      if (alertasEnZona.isNotEmpty) {
        _activarBadgePerimetroTemporal(alertasEnZona.length);
      }
      return;
    }

    bool hayNuevos = false;
    for (final r in reportes) {
      if (!_knownReportIds.contains(r.idReporte)) {
        _knownReportIds.add(r.idReporte);
        hayNuevos = true;

        if (r.autorRef != _currentUser.uid) {
          final enRadio = LocationService.isWithinAlertRadius(
            userLat: center.latitude,
            userLng: center.longitude,
            alertLat: r.latitud,
            alertLng: r.longitud,
            radiusMeters: 500,
          );

          if (enRadio) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: r.tipo == FirebaseConstants.tipoBotonPanico
                    ? AppColors.panicRed
                    : AppColors.primaryDark,
                duration: const Duration(seconds: 5),
                content: Row(
                  children: [
                    Icon(
                      r.tipo == FirebaseConstants.tipoBotonPanico
                          ? Icons.emergency
                          : Icons.warning_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '¡Alerta de Proximidad! Nuevo reporte a menos de 500m.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: 'Centrar',
                  textColor: Colors.white,
                  onPressed: () {
                    _mapController.move(LatLng(r.latitud, r.longitud), 17.5);
                  },
                ),
              ),
            );
          }
        }
      }
    }

    if (hayNuevos && alertasEnZona.isNotEmpty) {
      _activarBadgePerimetroTemporal(alertasEnZona.length);
    }
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

  Future<void> _abrirPerfil() async {
    final updated = await Navigator.push<UserEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioScreen(currentUser: _currentUser),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }

  void _abrirReporteSemanal(List<ReporteEntity> reportes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReporteSemanalScreen(
          reportes: reportes,
          sectorNombre: _currentUser.juntaVecinal ?? 'Sector Comunitario',
        ),
      ),
    );
  }

  void _mostrarMenuAlertasZona(List<ReporteEntity> alertasEnZona) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.fmd_good, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alertas Activas en tu Zona (500m)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        '${alertasEnZona.length} incidentes dentro del perímetro de seguridad',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            if (alertasEnZona.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: const [
                    Icon(Icons.shield_outlined, size: 48, color: AppColors.successGreen),
                    SizedBox(height: 10),
                    Text(
                      'Zona Segura y Tranquila',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.successGreen),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No se registran alertas activas en tu perímetro de 500 metros.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alertasEnZona.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rep = alertasEnZona[index];
                    final color = _getColorForTipo(rep.tipo);
                    final icon = _getIconForTipo(rep.tipo);

                    int distanciaMetros = 0;
                    if (_currentLatLng != null) {
                      distanciaMetros = GeoUtils.haversineDistanceMeters(
                        lat1: _currentLatLng!.latitude,
                        lon1: _currentLatLng!.longitude,
                        lat2: rep.latitud,
                        lon2: rep.longitud,
                      ).round();
                    }

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        title: Text(
                          rep.tipo.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                        ),
                        subtitle: Text(
                          'A $distanciaMetros m de ti • ${rep.contadorValidaciones} confirmaciones',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _mapController.move(LatLng(rep.latitud, rep.longitud), 17.5);
                            _showIncidentBottomSheet(rep);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Ver', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
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

      // 4. Sincronizar geofencing territorial y suscripción push en segundo plano
      NotificationService.updateUserLocationAndSector(
        uid: _currentUser.uid,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
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
              isOwner: reporte.autorRef == _currentUser.uid,
              currentUserId: _currentUser.uid,
              onValidar: () async {
                await _validarReporteUseCase.call(
                  idReporte: reporte.idReporte,
                  validadorUid: _currentUser.uid,
                );
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

  Color _getRoleThemeColor() {
    if (_currentUser.isDirigente) return const Color(0xFFD97706);
    if (_currentUser.isInstitucional) return const Color(0xFF1E3A8A);
    return AppColors.primary;
  }

  IconData _getRoleIcon() {
    if (_currentUser.isDirigente) return Icons.workspace_premium;
    if (_currentUser.isInstitucional) return Icons.local_police;
    return Icons.shield;
  }

  String _getRoleDisplayName() {
    if (_currentUser.isDirigente) return 'DIRIGENTE VECINAL';
    if (_currentUser.isInstitucional) return 'CARABINEROS / PDI';
    return _currentUser.rol.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleThemeColor();
    final roleIcon = _getRoleIcon();

    return Scaffold(
      body: StreamBuilder<List<ReporteEntity>>(
        stream: _reportesStream,
        builder: (context, snapshot) {
          final reportes = snapshot.data ?? [];
          final markers = _buildIncidentMarkers(reportes);

          // Filtrar alertas que se encuentran exclusivamente en el radio perimetral de 500m (Geofencing)
          final center = _currentLatLng ?? _defaultLocation;
          final alertasEnZona = reportes.where((rep) {
            return LocationService.isWithinAlertRadius(
              userLat: center.latitude,
              userLng: center.longitude,
              alertLat: rep.latitud,
              alertLng: rep.longitud,
              radiusMeters: 500,
            );
          }).toList();

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
                      tileProvider: widget.tileProvider,
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
                                color: roleColor,
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

              // 2. Barra Superior Flotante: Identidad Ciudadana, Rol y Perfil
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white.withOpacity(0.96),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _abrirPerfil,
                          borderRadius: BorderRadius.circular(20),
                          child: CircleAvatar(
                            backgroundColor: roleColor,
                            radius: 19,
                            child: Icon(roleIcon, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _abrirPerfil,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _currentUser.nombre?.isNotEmpty == true
                                            ? _currentUser.nombre!
                                            : _currentUser.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primaryDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_note_outlined, size: 16, color: AppColors.textSecondary),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${_getRoleDisplayName()} • ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: roleColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${_currentUser.reputacion} pts',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _currentUser.reputacion >= 70
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
                        ),
                        // Botón especial para Dirigente: Reporte Semanal Consolidado
                        if (_currentUser.isDirigente)
                          IconButton(
                            icon: const Icon(Icons.assessment_outlined, color: Color(0xFFD97706)),
                            tooltip: 'Reporte Semanal Consolidado',
                            onPressed: () => _abrirReporteSemanal(reportes),
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
                                  : 'Ubicación activa (${_currentUser.ciudad ?? 'Chile'})'),
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

              // 4. Botón Flotante para Menú de Alertas Activas en la Zona (500m)
              Positioned(
                right: 16,
                bottom: 245,
                child: FloatingActionButton.extended(
                  key: const Key('zone_alerts_button'),
                  heroTag: 'btn_zone_alerts',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  icon: const Icon(Icons.fmd_good_rounded, color: AppColors.primary, size: 20),
                  label: Text(
                    'Zona (${alertasEnZona.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _mostrarMenuAlertasZona(alertasEnZona),
                ),
              ),

              // 5. Botón Flotante para Recentrar en la posición del Usuario (Geolocator)
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

              // 6. Panel Inferior Flotante: Contador Dinámico, Botón de Pánico y Crear Reporte
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chip dinámico temporal: aparece cuando se genera un nuevo reporte en la zona y desaparece solo
                    if (_showPerimeterCount && _perimeterCount > 0)
                      AnimatedOpacity(
                        opacity: _showPerimeterCount ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: const Key('dynamic_perimeter_chip'),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                                '$_perimeterCount Incidentes en el perímetro',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Fila de acciones principales
                    Row(
                      children: [
                        // Botón de Pánico SOS (Sincronizado con máxima prioridad)
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

                                // Sincronización instantánea del pánico en toda la zona
                                await _crearReporteUseCase
                                    .dispararBotonPanico(
                                      autorUid: _currentUser.uid,
                                      latitud: latLng.latitude,
                                      longitud: latLng.longitude,
                                    )
                                    .timeout(
                                      const Duration(seconds: 4),
                                      onTimeout: () {
                                        debugPrint('[HomeView] SOS enviado con persistencia local.');
                                        return 'sos_timeout';
                                      },
                                    );

                                _mapController.move(latLng, 17.0);

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.panicRed,
                                    content: Text('¡ALERTA DE PÁNICO ENVIADA A LA COMUNIDAD!'),
                                    duration: Duration(seconds: 4),
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
                                    currentUserId: _currentUser.uid,
                                    crearReporteUseCase: _crearReporteUseCase,
                                    initialLat: _currentLatLng?.latitude,
                                    initialLng: _currentLatLng?.longitude,
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
