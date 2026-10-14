abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Ocurrió un error en el servidor. Intente más tarde.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Credenciales inválidas o usuario no registrado.']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'No fue posible acceder a la señal GPS del dispositivo.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Debe conceder los permisos requeridos para continuar.']);
}
