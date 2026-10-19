import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:civitas/core/theme/app_theme.dart';
import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/home/presentation/screens/home_view.dart';
import 'package:civitas/features/reportes/domain/entities/reporte_entity.dart';
import 'package:civitas/features/reportes/domain/usecases/crear_reporte_usecase.dart';
import 'package:civitas/features/reportes/domain/usecases/get_reportes_cercanos_usecase.dart';
import 'package:civitas/features/reportes/domain/usecases/validar_reporte_usecase.dart';
import 'mocks/mock_location_service.dart';
import 'mocks/mock_reportes_repository.dart';

class MockTileProvider extends TileProvider {
  MockTileProvider({super.headers});

  static final Uint8List _transparentPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}

void main() {
  group('HomeView - Pruebas de Integración con OpenStreetMap y Geolocalización', () {
    late MockLocationService mockLocationService;
    late MockReportesRepository mockReportesRepository;
    late CrearReporteUseCase crearReporteUseCase;
    late GetReportesCercanosUseCase getReportesUseCase;
    late ValidarReporteUseCase validarReporteUseCase;

    const mockUser = UserEntity(
      uid: 'user_456',
      email: 'vecino.lider@civitas.cl',
      rol: 'vecino',
      reputacion: 95,
    );

    setUp(() {
      mockLocationService = MockLocationService();
      mockReportesRepository = MockReportesRepository();
      crearReporteUseCase = CrearReporteUseCase(mockReportesRepository);
      getReportesUseCase = GetReportesCercanosUseCase(mockReportesRepository);
      validarReporteUseCase = ValidarReporteUseCase(mockReportesRepository);
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeView(
          currentUser: mockUser,
          locationService: mockLocationService,
          crearReporteUseCase: crearReporteUseCase,
          getReportesUseCase: getReportesUseCase,
          validarReporteUseCase: validarReporteUseCase,
          tileProvider: MockTileProvider(),
        ),
      );
    }

    testWidgets('1. Renderiza OpenStreetMap a pantalla completa y los controles flotantes', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. OpenStreetMap (FlutterMap) montado en el árbol de widgets
      expect(find.byKey(const Key('home_osm_map')), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      // 2. Información del ciudadano en la barra superior flotante
      expect(find.text('vecino.lider@civitas.cl'), findsOneWidget);
      expect(find.text('95 pts'), findsOneWidget);

      // 3. Botón flotante para recentrar GPS
      expect(find.byKey(const Key('recenter_gps_button')), findsOneWidget);

      // 4. Botón de Pánico SOS y Botón Reportar
      expect(find.byKey(const Key('home_panic_button')), findsOneWidget);
      expect(find.byKey(const Key('home_report_button')), findsOneWidget);
    });

    testWidgets('2. El botón de recentrar activa el servicio de geolocalización', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final recenterBtn = find.byKey(const Key('recenter_gps_button'));
      expect(recenterBtn, findsOneWidget);

      // Simular toque en el botón de recentrado GPS
      await tester.tap(recenterBtn);
      await tester.pumpAndSettle();

      // Debe haber consultado permisos y obtenido la posición actual
      expect(mockLocationService.handlePermissionCalls, greaterThanOrEqualTo(1));
      expect(mockLocationService.getCurrentLatLngCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('3. El Botón de Pánico SOS dispara una alerta inmediata a la comunidad', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final panicBtn = find.byKey(const Key('home_panic_button'));
      expect(panicBtn, findsOneWidget);

      // Disparar botón de pánico
      await tester.tap(panicBtn);
      await tester.pumpAndSettle();

      // Verificar que el caso de uso del repositorio de reportes fue invocado
      expect(mockReportesRepository.panicCalls, equals(1));
      expect(find.text('¡ALERTA DE PÁNICO ENVIADA A LA COMUNIDAD!'), findsOneWidget);
    });

    testWidgets('4. Pinta dinámicamente los marcadores cuando el Stream emite reportes activos', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Emitir 2 reportes activos en el Stream
      final now = DateTime.now();
      mockReportesRepository.emitReportes([
        ReporteEntity(
          idReporte: 'rep_1',
          autorRef: 'vecino_a',
          tipo: 'robo_vehiculo',
          latitud: -23.6510,
          longitud: -70.3980,
          geohash: '66jbs7m',
          estado: 'ACTIVO',
          contadorValidaciones: 2,
          timestamp: now,
        ),
        ReporteEntity(
          idReporte: 'rep_2',
          autorRef: 'vecino_b',
          tipo: 'actividad_sospechosa',
          latitud: -23.6520,
          longitud: -70.3990,
          geohash: '66jbs7n',
          estado: 'ACTIVO',
          contadorValidaciones: 1,
          timestamp: now,
        ),
      ]);

      await tester.pump();

      // Verificar que el contador flotante se actualiza dinámicamente a 2
      expect(find.text('2 Incidentes en el perímetro'), findsOneWidget);

      // Verificar que los marcadores de incidentes se renderizaron en el mapa
      expect(find.byKey(const Key('home_osm_map')), findsOneWidget);
      expect(find.byKey(const Key('marker_rep_1')), findsOneWidget);
      expect(find.byKey(const Key('marker_rep_2')), findsOneWidget);
    });
  });
}
