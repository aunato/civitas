import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/core/constants/firebase_constants.dart';
import 'package:civitas/core/theme/app_theme.dart';
import 'package:civitas/features/auth/domain/entities/user_entity.dart';
import 'package:civitas/features/auth/domain/usecases/login_usecase.dart';
import 'package:civitas/features/auth/domain/usecases/register_usecase.dart';
import 'package:civitas/features/auth/domain/usecases/verify_role_usecase.dart';
import 'package:civitas/features/auth/presentation/screens/login_view.dart';
import 'mocks/mock_auth_repository.dart';

void main() {
  group('Flujo de Verificación de Roles Institucionales (Carabineros / PDI)', () {
    late MockAuthRepository mockAuthRepository;
    late RegisterUseCase registerUseCase;
    late VerifyRoleUseCase verifyRoleUseCase;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      registerUseCase = RegisterUseCase(mockAuthRepository);
      verifyRoleUseCase = VerifyRoleUseCase(mockAuthRepository);
    });

    test('1. Vecino común se registra directamente con estado VERIFICADO', () async {
      final user = await registerUseCase.call(
        email: 'vecino@civitas.cl',
        password: 'password123',
        rol: FirebaseConstants.rolVecino,
      );

      expect(user.rol, FirebaseConstants.rolVecino);
      expect(user.estadoVerificacion, 'VERIFICADO');
      expect(user.isVerificado, isTrue);
      expect(user.isPendingVerification, isFalse);
    });

    test('2. Funcionario institucional se registra en estado PENDING_VERIFICATION', () async {
      final officer = await registerUseCase.call(
        email: 'carabinero@civitas.cl',
        password: 'password123',
        rol: FirebaseConstants.rolInstitucional,
        institucion: 'Carabineros de Chile',
        placaInstitucional: 'CAR-49201',
        credencialUrl: 'credencial_car_49201.jpg',
      );

      expect(officer.rol, FirebaseConstants.rolInstitucional);
      expect(officer.estadoVerificacion, 'PENDING_VERIFICATION');
      expect(officer.isPendingVerification, isTrue);
      expect(officer.isVerificado, isFalse);
      expect(officer.placaInstitucional, 'CAR-49201');
      expect(officer.credencialUrl, 'credencial_car_49201.jpg');
    });

    test('3. Caso de uso VerifyRoleUseCase aprueba credencial pasando a VERIFICADO', () async {
      final officer = await registerUseCase.call(
        email: 'pdi@civitas.cl',
        password: 'password123',
        rol: 'pdi',
        institucion: 'Policía de Investigaciones (PDI)',
        placaInstitucional: 'PDI-9912',
      );

      expect(officer.isPendingVerification, isTrue);

      // Jefatura o Administrador aprueba la credencial
      await verifyRoleUseCase.updateStatus(
        uid: officer.uid,
        status: 'VERIFICADO',
      );

      final updated = await mockAuthRepository.getCurrentUser();
      expect(updated?.estadoVerificacion, 'VERIFICADO');
      expect(updated?.isVerificado, isTrue);
      expect(updated?.isPendingVerification, isFalse);
    });

    testWidgets('4. Widget test: Formulario muestra campos de placa y credencial al elegir rol institucional', (tester) async {
      final loginUseCase = LoginUseCase(mockAuthRepository);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LoginView(
            loginUseCase: loginUseCase,
            registerUseCase: registerUseCase,
          ),
        ),
      );

      // Pasar a modo registro
      await tester.tap(find.byKey(const Key('tab_register')));
      await tester.pumpAndSettle();

      // Inicialmente en rol Ciudadano no debe mostrar campos de placa
      expect(find.byKey(const Key('register_placa_field')), findsNothing);
      expect(find.byKey(const Key('upload_credential_button')), findsNothing);

      // Cambiar dropdown a Carabineros / PDI
      final rolDropdown = find.byType(DropdownButtonFormField<String>);
      await tester.tap(rolDropdown);
      await tester.pumpAndSettle();

      // Seleccionar opción institucional
      final institucionalItem = find.text('🚓 Carabineros / PDI').last;
      await tester.tap(institucionalItem);
      await tester.pumpAndSettle();

      // Ahora deben aparecer los campos de verificación institucional
      expect(find.text('Verificación de Identidad Policial'), findsOneWidget);
      expect(find.byKey(const Key('register_placa_field')), findsOneWidget);
      expect(find.byKey(const Key('upload_credential_button')), findsOneWidget);

      // Tocar botón para adjuntar credencial (asegurando visibilidad en pantalla con scroll)
      final uploadBtn = find.byKey(const Key('upload_credential_button'));
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Debe confirmar adjunción
      expect(find.textContaining('Credencial Adjuntada'), findsOneWidget);
    });
  });
}
