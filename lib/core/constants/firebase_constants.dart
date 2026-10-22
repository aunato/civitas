class FirebaseConstants {
  // Colecciones de Firestore (Según Especificación Técnica de Tesis)
  static const String colUsuarios = 'usuarios';
  static const String colReportes = 'reportes';
  
  // Roles de usuario
  static const String rolVecino = 'vecino';
  static const String rolDirigente = 'dirigente';
  static const String rolInstitucional = 'institucional';
  static const String rolAdmin = 'administrador';

  // Estados de Reporte
  static const String estadoActivo = 'ACTIVO';
  static const String estadoValidado = 'VALIDADO';
  static const String estadoCerrado = 'CERRADO';

  // Tipos de Incidente
  static const String tipoBotonPanico = 'boton_panico';
  static const String tipoRoboVehiculo = 'robo_vehiculo';
  static const String tipoActividadSospechosa = 'actividad_sospechosa';
  static const String tipoEmergenciaMedica = 'emergencia_medica';
  static const String tipoAsalto = 'asalto';

  // Reglas de negocio
  static const int radioAlertaMetros = 500; // Radio de alerta barrial 500m
  static const int umbralValidacionComunidad = 5; // Validaciones para pasar a VALIDADO
  static const int reputacionMinimaBloqueo = 30; // Puntaje mínimo de reputación
}
