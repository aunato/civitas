import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { ReporteDocument } from "../types";
import { FcmService } from "../services/fcmService";

const UMBRAL_VALIDACIONES = 5;

/**
 * Cloud Function Trigger: onReporteUpdated
 * Se ejecuta automáticamente cada vez que un documento en 'reportes/{reporteId}' es modificado.
 *
 * Regla de Negocio:
 * Si contador_validaciones >= 5 por confirmaciones comunitarias,
 * el estado cambia automáticamente a 'VALIDADO' y se despacha una alerta FCM.
 */
export const onReporteUpdated = onDocumentUpdated(
  {
    document: "reportes/{reporteId}",
    region: "us-central1", // O la región de tu proyecto (ej: southamerica-east1)
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      logger.warn("[CIVITAS-Trigger] Evento sin datos válidos (data is undefined).");
      return;
    }

    const reporteId = event.params.reporteId;
    const beforeData = change.before.data() as ReporteDocument | undefined;
    const afterData = change.after.data() as ReporteDocument | undefined;

    if (!afterData) {
      logger.info(`[CIVITAS-Trigger] Reporte ${reporteId} fue eliminado. Omitiendo.`);
      return;
    }

    const beforeContador = beforeData?.contador_validaciones ?? 0;
    const afterContador = afterData.contador_validaciones ?? 0;
    const beforeEstado = beforeData?.estado ?? "ACTIVO";
    const afterEstado = afterData.estado ?? "ACTIVO";

    logger.info(
      `[CIVITAS-Trigger] Actualización en reporte '${reporteId}'. ` +
        `Contador: ${beforeContador} -> ${afterContador} | Estado: ${beforeEstado} -> ${afterEstado}`
    );

    // =========================================================================
    // 1. CONTROL DE IDEMPOTENCIA Y PREVENCIÓN DE BUCLES INFINITOS
    // =========================================================================
    // Si el reporte ya fue validado previamente, no volver a disparar
    if (beforeEstado === "VALIDADO" && afterEstado === "VALIDADO") {
      logger.debug(
        `[CIVITAS-Trigger] El reporte ${reporteId} ya se encuentra 'VALIDADO'. Omitiendo ejecución redundante.`
      );
      return;
    }

    // Si aún no alcanza el umbral de 5 validaciones comunitarias
    if (afterContador < UMBRAL_VALIDACIONES) {
      logger.info(
        `[CIVITAS-Trigger] Reporte ${reporteId} cuenta con ${afterContador}/${UMBRAL_VALIDACIONES} validaciones. Aún en estado '${afterEstado}'.`
      );
      return;
    }

    // =========================================================================
    // 2. LÓGICA DE VALIDACIÓN COMUNITARIA (Umbral alcanzado: contador >= 5)
    // =========================================================================
    if (afterContador >= UMBRAL_VALIDACIONES && afterEstado !== "VALIDADO") {
      logger.info(
        `[CIVITAS-Trigger] 🎯 ¡UMBRAL ALCANZADO! El reporte ${reporteId} alcanzó ${afterContador} confirmaciones. ` +
          `Procediendo a cambiar estado a 'VALIDADO' y enviar FCM.`
      );

      try {
        // A. Actualizar estado en Firestore
        await change.after.ref.update({
          estado: "VALIDADO",
          validado_en: admin.firestore.FieldValue.serverTimestamp(),
          notificado_fcm: true,
        });

        logger.info(`[CIVITAS-Trigger] Documento ${reporteId} actualizado a estado 'VALIDADO'.`);

        // B. Preparar estructura y enviar notificación push mediante FCM
        const messageId = await FcmService.enviarNotificacionAlertaValidada(
          reporteId,
          {
            ...afterData,
            estado: "VALIDADO",
          }
        );

        logger.info(
          `[CIVITAS-Trigger] Proceso completado exitosamente para reporte ${reporteId}. FCM MessageId: ${messageId}`
        );

        // C. Registrar en historial de auditoría comunitaria
        await admin.firestore().collection("auditoria_validaciones").add({
          id_reporte: reporteId,
          tipo: afterData.tipo,
          validaciones_finales: afterContador,
          fecha: admin.firestore.FieldValue.serverTimestamp(),
          fcm_message_id: messageId,
        });
      } catch (error) {
        logger.error(
          `[CIVITAS-Trigger] Error al procesar la validación o despacho FCM para reporte ${reporteId}:`,
          error
        );
        throw error; // Permite reintento automático si está configurado en Cloud Functions
      }
    }
  }
);
