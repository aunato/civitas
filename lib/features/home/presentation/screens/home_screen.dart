import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../reportes/data/datasources/reportes_remote_datasource.dart';
import '../../../reportes/data/repositories/reportes_repository_impl.dart';
import '../../../reportes/domain/entities/reporte_entity.dart';
import '../../../reportes/domain/usecases/crear_reporte_usecase.dart';
import '../../../reportes/domain/usecases/get_reportes_cercanos_usecase.dart';
import '../../../reportes/domain/usecases/validar_reporte_usecase.dart';
import '../../../reportes/presentation/screens/crear_reporte_screen.dart';
import '../../../reportes/presentation/screens/mapa_alertas_screen.dart';
import '../../../reportes/presentation/widgets/boton_panico.dart';
import '../../../reportes/presentation/widgets/tarjeta_reporte.dart';

class HomeScreen extends StatefulWidget {
  final UserEntity currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CrearReporteUseCase _crearReporteUseCase;
  late final GetReportesCercanosUseCase _getReportesUseCase;
  late final ValidarReporteUseCase _validarReporteUseCase;

  @override
  void initState() {
    super.initState();
    final remoteDataSource = ReportesRemoteDataSourceImpl();
    final repository = ReportesRepositoryImpl(remoteDataSource: remoteDataSource);
    _crearReporteUseCase = CrearReporteUseCase(repository);
    _getReportesUseCase = GetReportesCercanosUseCase(repository);
    _validarReporteUseCase = ValidarReporteUseCase(repository);
  }

  void _irAlMapa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaAlertasScreen(
          currentUserId: widget.currentUser.uid,
          getReportesUseCase: _getReportesUseCase,
          validarReporteUseCase: _validarReporteUseCase,
        ),
      ),
    );
  }

  void _irACrearReporte() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CrearReporteScreen(
          currentUserId: widget.currentUser.uid,
          crearReporteUseCase: _crearReporteUseCase,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: _irAlMapa,
            tooltip: 'Ver Mapa de Seguridad',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner de Información de Reputación y Rol (Tesis de CIVITAS)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppColors.primaryDark,
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.email,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Rol: ${widget.currentUser.rol.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.currentUser.reputacion >= 70
                          ? AppColors.successGreen
                          : AppColors.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rep: ${widget.currentUser.reputacion} pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // HU-02: Botón de Pánico prominente en pantalla principal
            BotonPanico(
              userUid: widget.currentUser.uid,
              crearReporteUseCase: _crearReporteUseCase,
              onAlertaEnviada: () => setState(() {}),
            ),

            const SizedBox(height: 24),

            // Acciones Rápidas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _irAlMapa,
                      icon: const Icon(Icons.map, color: AppColors.primary),
                      label: const Text('Ver Mapa'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _irACrearReporte,
                      icon: const Icon(Icons.add_alert, color: Colors.white),
                      label: const Text('Reportar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Lista en Tiempo Real de Alertas Comunitarias
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Text(
                    'Alertas Comunitarias en Tiempo Real',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.panicRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'EN VIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.panicRed,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            StreamBuilder<List<ReporteEntity>>(
              stream: _getReportesUseCase.call(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final reportes = snapshot.data ?? [];
                if (reportes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No hay alertas activas en tu sector.\nTu comunidad se encuentra tranquila.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reportes.length,
                  itemBuilder: (context, index) {
                    final reporte = reportes[index];
                    return TarjetaReporte(
                      reporte: reporte,
                      isOwner: reporte.autorRef == widget.currentUser.uid,
                      onValidar: () async {
                        await _validarReporteUseCase.call(
                          idReporte: reporte.idReporte,
                          validadorUid: widget.currentUser.uid,
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
