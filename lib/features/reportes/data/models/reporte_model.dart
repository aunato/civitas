import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/reporte_entity.dart';

/// Modelo de datos de Firestore para la colección 'reportes' de CIVITAS.
class ReporteModel extends ReporteEntity {
  // Campos exactos solicitados para Firestore
  final String id_reporte;
  final String autor_ref;
  @override
  final String tipo;
  final GeoPoint coordenadas;
  @override
  final String geohash;
  @override
  final String estado;
  final int contador_validaciones;
  @override
  final DateTime timestamp;
  final String? evidencia_url;
  @override
  final List<String> validadores;

  ReporteModel({
    required this.id_reporte,
    required this.autor_ref,
    required this.tipo,
    required this.coordenadas,
    required this.geohash,
    this.estado = 'ACTIVO',
    this.contador_validaciones = 0,
    required this.timestamp,
    this.evidencia_url,
    this.validadores = const [],
  }) : super(
          idReporte: id_reporte,
          autorRef: autor_ref,
          tipo: tipo,
          latitud: coordenadas.latitude,
          longitud: coordenadas.longitude,
          geohash: geohash,
          estado: estado,
          contadorValidaciones: contador_validaciones,
          timestamp: timestamp,
          evidenciaUrl: evidencia_url,
          validadores: validadores,
        );

  /// Construye un ReporteModel a partir de un DocumentSnapshot de Cloud Firestore
  factory ReporteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReporteModel.fromMap(data, id: doc.id);
  }

  /// Construye un ReporteModel a partir de un Map
  factory ReporteModel.fromMap(Map<String, dynamic> data, {String? id}) {
    GeoPoint geo = const GeoPoint(0.0, 0.0);
    if (data['coordenadas'] is GeoPoint) {
      geo = data['coordenadas'] as GeoPoint;
    } else if (data['latitud'] != null && data['longitud'] != null) {
      geo = GeoPoint(
        (data['latitud'] as num).toDouble(),
        (data['longitud'] as num).toDouble(),
      );
    }

    DateTime time = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      time = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp'] is DateTime) {
      time = data['timestamp'] as DateTime;
    }

    final valList = (data['validadores'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return ReporteModel(
      id_reporte: data['id_reporte'] as String? ?? id ?? '',
      autor_ref: data['autor_ref']?.toString() ?? '',
      tipo: data['tipo'] as String? ?? 'actividad_sospechosa',
      coordenadas: geo,
      geohash: data['geohash'] as String? ?? '',
      estado: data['estado'] as String? ?? 'ACTIVO',
      contador_validaciones: (data['contador_validaciones'] as num?)?.toInt() ?? 0,
      timestamp: time,
      evidencia_url: data['evidencia_url'] as String?,
      validadores: valList,
    );
  }

  /// Serializa el modelo al formato de documento de Cloud Firestore
  /// Utiliza FieldValue.serverTimestamp() para garantizar sincronización horaria
  Map<String, dynamic> toFirestore() {
    return {
      'id_reporte': id_reporte,
      'autor_ref': autor_ref,
      'tipo': tipo,
      'coordenadas': coordenadas,
      'geohash': geohash,
      'estado': estado,
      'contador_validaciones': contador_validaciones,
      'timestamp': FieldValue.serverTimestamp(),
      'evidencia_url': evidencia_url,
      'validadores': validadores,
    };
  }

  /// Conversión a Map con timestamp serializado (útil para pruebas y serialización local)
  Map<String, dynamic> toMap() {
    return {
      'id_reporte': id_reporte,
      'autor_ref': autor_ref,
      'tipo': tipo,
      'coordenadas': {
        'latitude': coordenadas.latitude,
        'longitude': coordenadas.longitude,
      },
      'geohash': geohash,
      'estado': estado,
      'contador_validaciones': contador_validaciones,
      'timestamp': timestamp.toIso8601String(),
      'evidencia_url': evidencia_url,
      'validadores': validadores,
    };
  }

  /// Crea una copia con campos modificados
  ReporteModel copyWith({
    String? id_reporte,
    String? autor_ref,
    String? tipo,
    GeoPoint? coordenadas,
    String? geohash,
    String? estado,
    int? contador_validaciones,
    DateTime? timestamp,
    String? evidencia_url,
    List<String>? validadores,
  }) {
    return ReporteModel(
      id_reporte: id_reporte ?? this.id_reporte,
      autor_ref: autor_ref ?? this.autor_ref,
      tipo: tipo ?? this.tipo,
      coordenadas: coordenadas ?? this.coordenadas,
      geohash: geohash ?? this.geohash,
      estado: estado ?? this.estado,
      contador_validaciones: contador_validaciones ?? this.contador_validaciones,
      timestamp: timestamp ?? this.timestamp,
      evidencia_url: evidencia_url ?? this.evidencia_url,
      validadores: validadores ?? this.validadores,
    );
  }
}
