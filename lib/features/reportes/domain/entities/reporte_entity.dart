class ReporteEntity {
  final String idReporte;
  final String autorRef; // UID o Referencia al usuario autor
  final String tipo; // 'boton_panico', 'robo_vehiculo', 'actividad_sospechosa', 'emergencia_medica'
  final double latitud;
  final double longitud;
  final String geohash;
  final String estado; // 'ACTIVO', 'VALIDADO', 'CERRADO'
  final int contadorValidaciones;
  final DateTime timestamp;
  final String? evidenciaUrl;
  final List<String> validadores;

  const ReporteEntity({
    required this.idReporte,
    required this.autorRef,
    required this.tipo,
    required this.latitud,
    required this.longitud,
    required this.geohash,
    required this.estado,
    required this.contadorValidaciones,
    required this.timestamp,
    this.evidenciaUrl,
    this.validadores = const [],
  });

  bool get isPanicAlert => tipo == 'boton_panico';
  bool get isValidated => estado == 'VALIDADO' || contadorValidaciones >= 5;
  bool isConfirmedBy(String uid) => validadores.contains(uid);
}
