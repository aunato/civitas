class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Error en el servidor de Firebase']);

  @override
  String toString() => 'ServerException: $message';
}

class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Error de autenticación']);

  @override
  String toString() => 'AuthException: $message';
}

class LocationException implements Exception {
  final String message;
  LocationException([this.message = 'No se pudo obtener la ubicación GPS']);

  @override
  String toString() => 'LocationException: $message';
}

class PermissionException implements Exception {
  final String message;
  PermissionException([this.message = 'Permisos insuficientes']);

  @override
  String toString() => 'PermissionException: $message';
}
