import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../widgets/auth_text_field.dart';
import '../../../home/presentation/screens/home_view.dart';

class LoginView extends StatefulWidget {
  final LoginUseCase? loginUseCase;
  final RegisterUseCase? registerUseCase;

  const LoginView({
    super.key,
    this.loginUseCase,
    this.registerUseCase,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String _selectedRol = FirebaseConstants.rolVecino;

  late final LoginUseCase _loginUseCase;
  late final RegisterUseCase _registerUseCase;

  @override
  void initState() {
    super.initState();
    if (widget.loginUseCase != null && widget.registerUseCase != null) {
      _loginUseCase = widget.loginUseCase!;
      _registerUseCase = widget.registerUseCase!;
    } else {
      try {
        final remoteDataSource = AuthRemoteDataSourceImpl();
        final repository = AuthRepositoryImpl(remoteDataSource: remoteDataSource);
        _loginUseCase = widget.loginUseCase ?? LoginUseCase(repository);
        _registerUseCase = widget.registerUseCase ?? RegisterUseCase(repository);
      } catch (_) {
        final fallbackRepo = _FallbackAuthRepository();
        _loginUseCase = widget.loginUseCase ?? LoginUseCase(fallbackRepo);
        _registerUseCase = widget.registerUseCase ?? RegisterUseCase(fallbackRepo);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _enterDemoMode({String rol = 'vecino'}) {
    FocusScope.of(context).unfocus();
    final UserEntity demoUser;
    if (rol == FirebaseConstants.rolDirigente) {
      demoUser = const UserEntity(
        uid: 'dirigente_demo_01',
        email: 'dirigente.demo@civitas.cl',
        rol: 'dirigente',
        reputacion: 100,
        nombre: 'Presidente Junta Vecinal N°12',
        ciudad: 'Alto Hospicio',
        juntaVecinal: 'Junta de Vecinos Santa Rosa',
      );
    } else if (rol == FirebaseConstants.rolInstitucional) {
      demoUser = const UserEntity(
        uid: 'institucional_demo_01',
        email: 'seguridad.demo@civitas.cl',
        rol: 'institucional',
        reputacion: 100,
        nombre: 'Oficial de Guardia Carabineros / PDI',
        ciudad: 'Alto Hospicio',
      );
    } else {
      demoUser = const UserEntity(
        uid: 'vecino_demo_01',
        email: 'vecino.demo@civitas.cl',
        rol: 'vecino',
        reputacion: 100,
        nombre: 'Vecino Ciudadano',
        ciudad: 'Alto Hospicio',
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeView(currentUser: demoUser)),
    );
  }

  void _showRoleDemoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),
            const Text(
              'Seleccione Rol para Acceso Directo (Demo)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Evaluación de interfaces según privilegios de usuario en CIVITAS',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDemoRoleTile(
              title: 'Ciudadano / Vecino',
              subtitle: 'Alertas en mapa, geofencing 500m y botón de pánico SOS',
              icon: Icons.person_outline,
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(ctx);
                _enterDemoMode(rol: FirebaseConstants.rolVecino);
              },
            ),
            const SizedBox(height: 10),
            _buildDemoRoleTile(
              title: 'Presidente Junta Vecinal',
              subtitle: 'Acceso a reporte semanal consolidado y exportación de datos',
              icon: Icons.workspace_premium_outlined,
              color: const Color(0xFFD97706),
              onTap: () {
                Navigator.pop(ctx);
                _enterDemoMode(rol: FirebaseConstants.rolDirigente);
              },
            ),
            const SizedBox(height: 10),
            _buildDemoRoleTile(
              title: 'Carabineros / PDI (Institucional)',
              subtitle: 'Fiscalización de cuadrante y monitoreo oficial de seguridad',
              icon: Icons.local_police_outlined,
              color: const Color(0xFF1E3A8A),
              onTap: () {
                Navigator.pop(ctx);
                _enterDemoMode(rol: FirebaseConstants.rolInstitucional);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoRoleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _fillDemoCredentials() {
    setState(() {
      _isRegisterMode = false;
      _emailController.text = 'vecino.demo@civitas.cl';
      _passwordController.text = 'civitas123';
      _errorMessage = null;
    });
  }

  Future<void> _submitAuth() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_isRegisterMode && _passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Las contraseñas no coinciden';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final UserEntity user;
      if (_isRegisterMode) {
        user = await _registerUseCase.call(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rol: _selectedRol,
        );
      } else {
        user = await _loginUseCase.call(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;

      if (user.isBlocked) {
        setState(() {
          _errorMessage = 'Cuenta suspendida por baja reputación comunitaria (<30 pts).';
          _isLoading = false;
        });
        return;
      }

      if (_isRegisterMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada con éxito! Bienvenido a CIVITAS.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeView(currentUser: user)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is AuthException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = e.toString().replaceAll('AuthException: ', '').replaceAll('Exception: ', '');
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo e Iconografía Institucional
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.shield_rounded,
                        size: 52,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Título y Bajada
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppConstants.appTagline,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contenedor tipo Tarjeta Moderna
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Selector de pestaña (Ingreso / Registro)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    key: const Key('tab_login'),
                                    onTap: () {
                                      if (_isRegisterMode) {
                                        setState(() {
                                          _isRegisterMode = false;
                                          _errorMessage = null;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: !_isRegisterMode ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        'Ingresar',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: !_isRegisterMode ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    key: const Key('tab_register'),
                                    onTap: () {
                                      if (!_isRegisterMode) {
                                        setState(() {
                                          _isRegisterMode = true;
                                          _errorMessage = null;
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 9),
                                      decoration: BoxDecoration(
                                        color: _isRegisterMode ? AppColors.primary : Colors.transparent,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Text(
                                        'Registrarse',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _isRegisterMode ? Colors.white : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Título dinámico
                          Text(
                            _isRegisterMode ? 'Registro Vecinal y Roles' : 'Ingreso Vecinal',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRegisterMode
                                ? 'Crea tu cuenta seleccionando tu perfil ciudadano o institucional'
                                : 'Accede a la red comunitaria de alerta temprana',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 18),

                          // Banner de error si existe
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.panicRed.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.panicRed.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.panicRed, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.panicRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Selector de Rol si está en modo registro
                          if (_isRegisterMode) ...[
                            DropdownButtonFormField<String>(
                              value: _selectedRol,
                              decoration: const InputDecoration(
                                labelText: 'Rol / Perfil en CIVITAS',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: FirebaseConstants.rolVecino,
                                  child: Text('👤 Ciudadano / Vecino'),
                                ),
                                DropdownMenuItem(
                                  value: FirebaseConstants.rolDirigente,
                                  child: Text('🏛️ Presidente / Dirigente Junta Vecinal'),
                                ),
                                DropdownMenuItem(
                                  value: FirebaseConstants.rolInstitucional,
                                  child: Text('🚓 Carabineros / PDI / Seguridad'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedRol = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Campo Correo
                          AuthTextField(
                            key: const Key('login_email_field'),
                            controller: _emailController,
                            label: 'Correo Electrónico',
                            hint: 'vecino@civitas.cl',
                            prefixIcon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingrese su correo electrónico';
                              }
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Formato de correo inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Campo Contraseña
                          TextFormField(
                            key: const Key('login_password_field'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Ingrese su contraseña';
                              }
                              if (val.length < 6) {
                                return 'Debe tener al menos 6 caracteres';
                              }
                              return null;
                            },
                          ),

                          // Campo Confirmar Contraseña (solo en modo registro)
                          if (_isRegisterMode) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('register_confirm_password_field'),
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirmar Contraseña',
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Confirme su contraseña';
                                }
                                if (val != _passwordController.text) {
                                  return 'Las contraseñas no coinciden';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 22),

                          // Botón Principal (Iniciar Sesión / Crear Cuenta)
                          ElevatedButton(
                            key: const Key('login_submit_button'),
                            onPressed: _isLoading ? null : _submitAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isRegisterMode ? 'Crear Cuenta Vecinal' : 'Iniciar Sesión',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),

                          // Opciones de modo inicio de sesión
                          if (!_isRegisterMode) ...[
                            const SizedBox(height: 12),

                            // Botón de Acceso Rápido en Modo Demo (con selector de roles)
                            OutlinedButton.icon(
                              key: const Key('login_demo_button'),
                              onPressed: _isLoading ? null : _showRoleDemoModal,
                              icon: const Icon(Icons.bolt_rounded, color: AppColors.primary),
                              label: const Text(
                                'Acceso Rápido por Roles (Demo)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Tarjeta de credenciales de prueba para facilitar ingreso
                            InkWell(
                              onTap: _fillDemoCredentials,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.key_outlined, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Cuenta vecinal de prueba',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                          Text(
                                            'vecino.demo@civitas.cl / civitas123 (Toca para rellenar)',
                                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Enlace para alternar entre login y registro
                          TextButton(
                            key: const Key('auth_toggle_mode_button'),
                            onPressed: () {
                              setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              _isRegisterMode
                                  ? '¿Ya tienes una cuenta? Inicia sesión aquí'
                                  : '¿No tienes cuenta? Regístrate aquí',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Nota sobre protección de identidad (Ley 19.628 de la tesis)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_person_outlined, size: 15, color: AppColors.textSecondary),
                      SizedBox(width: 6),
                      Text(
                        'Identidad protegida conforme a la Ley 19.628',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackAuthRepository implements AuthRepository {
  @override
  Stream<UserEntity?> get authStateChanges => const Stream.empty();

  @override
  Future<UserEntity?> getCurrentUser() async => null;

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return UserEntity(
      uid: 'vecino_demo_01',
      email: email,
      rol: FirebaseConstants.rolVecino,
      reputacion: 100,
      nombre: 'Vecino Ciudadano',
      ciudad: 'Alto Hospicio',
    );
  }

  @override
  Future<UserEntity> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String rol,
  }) async {
    return UserEntity(
      uid: 'vecino_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      rol: rol,
      reputacion: 100,
      ciudad: 'Alto Hospicio',
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updateFcmToken(String uid, String token) async {}
}
