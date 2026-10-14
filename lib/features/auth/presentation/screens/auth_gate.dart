import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_auth_state_usecase.dart';
import 'login_view.dart';
import '../../../home/presentation/screens/home_view.dart';

/// Controla la persistencia de la sesión: Redirige automáticamente
/// a HomeView si hay sesión activa, o a LoginView si no la hay.
class AuthGate extends StatefulWidget {
  final GetAuthStateUseCase? getAuthStateUseCase;

  const AuthGate({super.key, this.getAuthStateUseCase});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final GetAuthStateUseCase _authStateUseCase;

  @override
  void initState() {
    super.initState();
    if (widget.getAuthStateUseCase != null) {
      _authStateUseCase = widget.getAuthStateUseCase!;
    } else {
      final remoteDataSource = AuthRemoteDataSourceImpl();
      final repository = AuthRepositoryImpl(remoteDataSource: remoteDataSource);
      _authStateUseCase = GetAuthStateUseCase(repository);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserEntity?>(
      stream: _authStateUseCase.call(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 72, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: AppColors.primary),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null && !user.isBlocked) {
          return HomeView(currentUser: user);
        }

        return const LoginView();
      },
    );
  }
}
