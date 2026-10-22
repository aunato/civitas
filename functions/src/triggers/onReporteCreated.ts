import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { ReporteDocument } from "../types";
import { FcmService } from "../services/fcmService";

/**
 * Cloud Function Trigger: onReporteCreated
 * Se ejecuta automáticamente tan pronto como un nuevo documento es insertado en 'reportes/{reporteId}'.
 *
 * Objetivo de Negocio:
 * Notificación instantánea en tiempo real y geofencing de 500m hacia los vecinos
 * del sector ante cualquier emergencia SOS o reporte ciudadano creado.
 */
export const onReporteCreated = onDocumentCreated(
  {
    document: "reportes/{reporteId}",
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("[CIVITAS-Trigger-Created] Evento sin snapshot de datos.");
      return;
    }

    const reporteId = event.params.reporteId;
    const data = snapshot.data() as ReporteDocument | undefined;

    if (!data) {
      logger.warn(`[CIVITAS-Trigger-Created] No se encontró contenido en el reporte ${reporteId}.`);
      return;
    }

    logger.info(
      `[CIVITAS-Trigger-Created] 🔔 Nuevo reporte detectado '${reporteId}'. Tipo: ${data.tipo}, Autor: ${data.autor_ref}`
    );

    try {
      // 1. Despacho instantáneo de notificaciones por Tópicos y Geofencing de 500 metros
      const resultado = await FcmService.despacharAlertaInmediata(reporteId, data);

      // 2. Marcar en Firestore que el reporte ya fue procesado y notificado
      await snapshot.ref.update({
        notificado_fcm: true,
        notificado_en: admin.firestore.FieldValue.serverTimestamp(),
        fcm_multicast_count: resultado.multicastSuccessCount,
      });

      // 3. Registrar en bitácora de auditoría de alertas
      await admin.firestore().collection("auditoria_alertas").add({
        id_reporte: reporteId,
        tipo: data.tipo,
        autor_ref: data.autor_ref,
        multicast_count: resultado.multicastSuccessCount,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(
        `[CIVITAS-Trigger-Created] Proceso completado exitosamente para reporte ${reporteId}. Vecinos notificados directamente: ${resultado.multicastSuccessCount}`
      );
    } catch (error) {
      logger.error(
        `[CIVITAS-Trigger-Created] Error procesando notificación inmediata para reporte ${reporteId}:`,
        error
      );
      // No re-lanzamos para no reintentar bucles en errores no recuperables
    }
  }
);
