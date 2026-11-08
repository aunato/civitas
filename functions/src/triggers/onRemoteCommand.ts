import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { FcmService } from "../services/fcmService";

/**
 * Cloud Function Trigger: onRemoteCommandRequested
 * Escucha la creación de peticiones en 'comandos_remotos/{cmdId}'
 * para despachar comandos de seguridad y antirrobo de alta prioridad vía FCM:
 * - CMD_FORCE_GPS: Triangulación satelital forzada
 * - CMD_START_AUDIO_STREAM: Grabación sigilosa de audio ambiental
 */
export const onRemoteCommandRequested = onDocumentCreated(
  {
    document: "comandos_remotos/{cmdId}",
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const cmdId = event.params.cmdId;
    const targetUid = data.target_uid || data.targetUid;
    const command = data.comando || data.command;

    if (!targetUid || !command) {
      logger.warn(`[RemoteCommand] Petición ${cmdId} incompleta (falta targetUid o comando).`);
      return;
    }

    try {
      const userDoc = await admin.firestore().collection("usuarios").doc(targetUid).get();
      if (!userDoc.exists) {
        logger.warn(`[RemoteCommand] Usuario destino ${targetUid} no encontrado en Firestore.`);
        return;
      }

      const fcmToken = userDoc.data()?.fcm_token;
      if (!fcmToken) {
        logger.warn(`[RemoteCommand] Usuario ${targetUid} no posee fcm_token registrado.`);
        return;
      }

      const messageId = await FcmService.despacharComandoRemoto(
        fcmToken,
        targetUid,
        command as "CMD_FORCE_GPS" | "CMD_START_AUDIO_STREAM"
      );

      await snapshot.ref.update({
        despachado: true,
        fcm_message_id: messageId,
        despachado_en: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`[RemoteCommand] Comando ${command} despachado exitosamente para ${targetUid}`);
    } catch (error) {
      logger.error(`[RemoteCommand] Error ejecutando comando para ${targetUid}:`, error);
      await snapshot.ref.update({
        error: String(error),
        fallido_en: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);
