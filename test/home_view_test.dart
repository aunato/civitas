import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:civitas/core/theme/app_theme.dart';
import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/home/presentation/screens/home_view.dart';
import 'package:civitas/features/reportes/domain/entities/reporte_entity.dart';
import 'package:civitas/features/reportes/domain/usecases/crear_reporte_usecase.dart';
import 'package:civitas/features/reportes/domain/usecases/get_reportes_cercanos_usecase.dart';
import 'package:civitas/features/reportes/domain/usecases/validar_reporte_usecase.dart';
import 'mocks/mock_location_service.dart';
import 'mocks/mock_reportes_repository.dart';

void main() {
  group('HomeView - Pruebas de Integración con GoogleMap y Geolocalización', () {
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
        ),
      );
    }

    testWidgets('1. Renderiza GoogleMap a pantalla completa y los controles flotantes', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // 1. GoogleMap montado en el árbol de widgets
      expect(find.byKey(const Key('home_google_map')), findsOneWidget);

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

      // Verificar que el widget GoogleMap recibió los marcadores
      final googleMapWidget = tester.widget<GoogleMap>(find.byKey(const Key('home_google_map')));
      expect(googleMapWidget.markers.length, equals(2));
      expect(googleMapWidget.markers.any((m) => m.markerId.value == 'rep_1'), isTrue);
      expect(googleMapWidget.markers.any((m) => m.markerId.value == 'rep_2'), isTrue);
    });
  });
}
