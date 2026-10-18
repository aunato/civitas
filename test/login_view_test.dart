import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civitas/core/theme/app_theme.dart';
import 'package:civitas/features/auth/domain/usecases/login_usecase.dart';
import 'package:civitas/features/auth/presentation/screens/login_view.dart';
import 'mocks/mock_auth_repository.dart';

void main() {
  group('LoginView - Pruebas de Integración de Widgets', () {
    late MockAuthRepository mockAuthRepository;
    late LoginUseCase loginUseCase;

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      loginUseCase = LoginUseCase(mockAuthRepository);
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: LoginView(loginUseCase: loginUseCase),
      );
    }

    testWidgets('1. Renderiza los elementos esenciales del diseño limpio y moderno', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Verificar branding e iconografía
      expect(find.text('CIVITAS'), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      expect(find.text('Ingreso Vecinal'), findsOneWidget);

      // Verificar campos de formulario
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);

      // Verificar botón de acción principal
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('2. Valida campos obligatorios y formato de correo electrónico', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Presionar Iniciar Sesión con campos vacíos
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Debe mostrar advertencias de validación
      expect(find.text('Ingrese su correo electrónico'), findsOneWidget);
      expect(find.text('Ingrese su contraseña'), findsOneWidget);

      // Ingresar correo sin formato válido
      await tester.enterText(find.byKey(const Key('login_email_field')), 'correo_invalido');
      await tester.enterText(find.byKey(const Key('login_password_field')), '123456');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Formato de correo inválido'), findsOneWidget);
    });

    testWidgets('3. Permite alternar la visibilidad de la contraseña', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Inicialmente la contraseña está oculta con el icono visibility_off
      final toggleIcon = find.byIcon(Icons.visibility_off);
      expect(toggleIcon, findsOneWidget);

      // Presionar toggle para hacer visible la contraseña
      await tester.tap(toggleIcon);
      await tester.pumpAndSettle();

      // Ahora el icono debe cambiar a visibility
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('4. Muestra banner de error ante credenciales incorrectas', (tester) async {
      mockAuthRepository.shouldFail = true;

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byKey(const Key('login_email_field')), 'vecino@civitas.cl');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Verifica mensaje de error renderizado
      expect(find.text('Credenciales incorrectas o usuario no encontrado.'), findsOneWidget);
    });

    testWidgets('5. Permite alternar a modo registro y validar confirmación de contraseña', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Alternar a modo registro tocando la pestaña Registrarse
      await tester.tap(find.byKey(const Key('tab_register')));
      await tester.pumpAndSettle();

      // Debe mostrar el formulario de Registro Vecinal
      expect(find.text('Registro Vecinal'), findsOneWidget);
      expect(find.text('Crear Cuenta Vecinal'), findsOneWidget);
      expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);

      // Probar validación de contraseñas no coincidentes
      await tester.enterText(find.byKey(const Key('login_email_field')), 'nuevo.vecino@civitas.cl');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'clave123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'distinta123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });
  });
}

