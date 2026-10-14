import * as admin from "firebase-admin";

export type TipoIncidente =
  | "boton_panico"
  | "robo_vehiculo"
  | "actividad_sospechosa"
  | "emergencia_medica"
  | "asalto"
  | string;

export type EstadoReporte = "ACTIVO" | "VALIDADO" | "CERRADO";

export interface ReporteDocument {
  id_reporte: string;
  autor_ref: string;
  tipo: TipoIncidente;
  coordenadas: admin.firestore.GeoPoint;
  geohash: string;
  estado: EstadoReporte;
  contador_validaciones: number;
  timestamp: admin.firestore.Timestamp;
  evidencia_url?: string | null;
  validado_en?: admin.firestore.Timestamp;
  notificado_fcm?: boolean;
}
