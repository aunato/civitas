import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/auth/domain/usecases/complete_profile_usecase.dart';
import 'package:civitas/features/auth/presentation/screens/onboarding_wizard_screen.dart';
import 'package:civitas/features/network/domain/entities/trusted_contact_entity.dart';
import 'package:civitas/features/network/domain/entities/trust_request_entity.dart';
import 'package:civitas/features/network/presentation/screens/red_confianza_screen.dart';
import 'package:civitas/features/network/presentation/widgets/credencial_civitas_badge.dart';
import 'mocks/mock_auth_repository.dart';
import 'mocks/mock_network_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding & Red de Confianza Domain & Entities Tests', () {
    test('UserEntity maneja isProfileComplete correctamente', () {
      const defaultUser = UserEntity(
        uid: 'user_1',
        email: 'vecino@civitas.cl',
        rol: 'vecino',
        reputacion: 100,
      );
      // Por compatibilidad con tests existentes el default es true
      expect(defaultUser.isProfileComplete, isTrue);

      final newUser = defaultUser.copyWith(isProfileComplete: false);
      expect(newUser.isProfileComplete, isFalse);
    });

    test('CompleteProfileUseCase actualiza datos y marca perfil como completo', () async {
      final mockAuth = MockAuthRepository();
      final useCase = CompleteProfileUseCase(mockAuth);

      final completedUser = await useCase.call(
        uid: 'user_new_123',
        nombre: 'Felipe Vecino Activo',
        rut: '19.876.543-2',
        telefono: '+56912348899',
        ciudad: 'Iquique',
        direccion: 'Av. Costanera 450',
        juntaVecinal: 'Cavancha',
      );

      expect(completedUser.isProfileComplete, isTrue);
      expect(completedUser.nombre, equals('Felipe Vecino Activo'));
      expect(completedUser.rut, equals('19.876.543-2'));
      expect(completedUser.ciudad, equals('Iquique'));
    });
  });

  group('CredencialCivitasBadge Widget Tests', () {
    testWidgets('CredencialCivitasBadge muestra datos de seguridad requeridos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CredencialCivitasBadge(
              nombre: 'Juan Pérez Silva',
              rut: '12.345.678-9',
              rol: 'Vecino Activo',
              reputacion: 100,
              folio: 'CIVITAS-CL-JP2026',
            ),
          ),
        ),
      );

      expect(find.text('CREDENCIAL CIVITAS DIGITAL'), findsOneWidget);
      expect(find.text('Juan Pérez Silva'), findsOneWidget);
      expect(find.text('RUT: 12.345.678-9'), findsOneWidget);
      expect(find.text('CIVITAS-CL-JP2026'), findsOneWidget);
      expect(find.text('VIGENTE'), findsOneWidget);
      expect(find.text('100 PTS'), findsOneWidget);
    });

    testWidgets('CredencialCivitasBadge en modo compacto muestra folio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CredencialCivitasBadge(
              nombre: 'Juan Pérez',
              rol: 'Vecino',
              folio: 'CIVITAS-CL-999',
              isCompact: true,
            ),
          ),
        ),
      );

      expect(find.text('CIVITAS: CIVITAS-CL-999'), findsOneWidget);
    });
  });

  group('RedConfianzaScreen Widget Tests', () {
    late MockNetworkRepository mockNetwork;
    late UserEntity testUser;

    setUp(() {
      mockNetwork = MockNetworkRepository();
      testUser = const UserEntity(
        uid: 'user_main_1',
        email: 'vecino.test@civitas.cl',
        nombre: 'Mario Guarda',
        telefono: '+56977665544',
        rol: 'vecino',
        reputacion: 100,
        rut: '15.432.109-8',
        isProfileComplete: true,
      );
    });

    testWidgets('Muestra contactos de confianza y solicitudes pendientes', (tester) async {
      // Agregar un contacto previo
      mockNetwork.trustedContacts.add(
        TrustedContactEntity(
          id: 'contact_existente',
          name: 'Juana Soto',
          phone: '+56911223344',
          relationship: 'Vecino de Confianza',
          isVerified: true,
          addedAt: DateTime(2026, 11, 8),
        ),
      );

      // Agregar una solicitud pendiente con credencial
      mockNetwork.pendingRequests.add(
        TrustRequestEntity(
          id: 'req_sol_1',
          fromUid: 'vecino_solicitante_uid',
          fromName: 'Carlos Salgado (Dirigente)',
          fromPhone: '+56999887711',
          fromRut: '14.555.666-7',
          fromRol: 'Dirigente Vecinal',
          fromReputacion: 100,
          fromCredencialFolio: 'CIVITAS-CL-DIR2026',
          toPhone: '+56977665544',
          status: 'PENDING',
          createdAt: DateTime(2026, 11, 8),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RedConfianzaScreen(
            currentUser: testUser,
            networkRepository: mockNetwork,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe verse el contacto en la pestaña Mi Red
      expect(find.text('Juana Soto'), findsOneWidget);
      expect(find.text('+56911223344'), findsOneWidget);

      // Cambiar a la pestaña Solicitudes
      await tester.tap(find.text('Solicitudes'));
      await tester.pumpAndSettle();

      // Debe verse la solicitud y la credencial de Carlos Salgado
      expect(find.text('Carlos Salgado (Dirigente)'), findsWidgets);
      expect(find.text('CIVITAS-CL-DIR2026'), findsOneWidget);
      expect(find.text('Aceptar Credencial'), findsOneWidget);

      // Aceptar la solicitud
      await tester.tap(find.text('Aceptar Credencial'));
      await tester.pumpAndSettle();

      // Debe abrir diálogo de vínculo confirmado
      expect(find.text('¡Vínculo de Seguridad Confirmado!'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // Volver a pestaña Mi Red y verificar que se añadió
      await tester.tap(find.textContaining('Mi Red'));
      await tester.pumpAndSettle();
      expect(find.text('Carlos Salgado (Dirigente)'), findsOneWidget);
    });

    testWidgets('Pestaña de Contactos telefónicos permite invitar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RedConfianzaScreen(
            currentUser: testUser,
            networkRepository: mockNetwork,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cambiar a la pestaña Contactos
      await tester.tap(find.text('Contactos'));
      await tester.pumpAndSettle();

      expect(find.text('Don Carlos (Vecino Pasaje A)'), findsOneWidget);
      expect(find.text('Invitar'), findsWidgets);

      // Tap en Invitar
      await tester.tap(find.text('Invitar').first);
      await tester.pumpAndSettle();

      expect(mockNetwork.pendingRequests.isNotEmpty, isTrue);
    });
  });

  group('OnboardingWizardScreen Widget Tests', () {
    late MockAuthRepository mockAuth;
    late MockNetworkRepository mockNetwork;
    late UserEntity incompleteUser;

    setUp(() {
      mockAuth = MockAuthRepository();
      mockNetwork = MockNetworkRepository();
      incompleteUser = const UserEntity(
        uid: 'user_onboard_1',
        email: 'nuevo.vecino@civitas.cl',
        nombre: 'Vecino Nuevo',
        telefono: '+56933445566',
        rol: 'vecino',
        reputacion: 100,
        rut: '',
        ciudad: 'Iquique',
        direccion: '',
        isProfileComplete: false,
      );
    });

    testWidgets('Completa los 3 pasos del wizard de Onboarding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            currentUser: incompleteUser,
            authRepository: mockAuth,
            networkRepository: mockNetwork,
            onCompleted: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Paso 1: Perfil Cívico
      expect(find.text('Paso 1: Tu Identidad Cívica'), findsOneWidget);

      // Llenar RUT obligatorio
      final rutField = find.widgetWithText(TextFormField, 'RUT / DNI (Ej: 18.234.567-K) *');
      await tester.enterText(rutField, '18.999.888-7');
      await tester.pumpAndSettle();

      // Avanzar al Paso 2
      final continueButton = find.text('Continuar');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Paso 2: Red de Confianza
      expect(find.text('Paso 2: Red de Confianza'), findsOneWidget);
      expect(find.text('Don Carlos (Vecino Pasaje A)'), findsOneWidget);

      // Avanzar al Paso 3
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Paso 3: Credencial CIVITAS
      expect(find.text('Paso 3: Tu Credencial CIVITAS'), findsOneWidget);
      expect(find.text('CREDENCIAL CIVITAS DIGITAL'), findsOneWidget);
      expect(find.text('Activar Credencial e Ingresar'), findsOneWidget);

      // Finalizar Onboarding
      final finishButton = find.text('Activar Credencial e Ingresar');
      await tester.tap(finishButton);
      await tester.pumpAndSettle();

      // El repositorio debe registrar el perfil completado
      final currentUser = await mockAuth.getCurrentUser();
      expect(currentUser?.isProfileComplete, isTrue);
      expect(currentUser?.rut, equals('18.999.888-7'));
    });
  });
}
