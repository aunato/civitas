import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { ReporteDocument, TipoIncidente } from "../types";

export class FcmService {
  /**
   * Obtiene la etiqueta amigable del tipo de incidente
   */
  private static getTipoLabel(tipo: TipoIncidente): string {
    switch (tipo) {
      case "boton_panico":
        return "BOTÓN DE PÁNICO SOS";
      case "robo_vehiculo":
        return "Robo de Vehículo";
      case "actividad_sospechosa":
        return "Actividad Sospechosa";
      case "emergencia_medica":
        return "Emergencia Médica Vecinal";
      case "asalto":
        return "Asalto o Intimidación";
      default:
        return tipo.replace(/_/g, " ").toUpperCase();
    }
  }

  /**
   * Construye y despacha las notificaciones push mediante Firebase Cloud Messaging (FCM)
   */
  public static async enviarNotificacionAlertaValidada(
    reporteId: string,
    reporte: ReporteDocument
  ): Promise<string> {
    const tipoLabel = this.getTipoLabel(reporte.tipo);
    const numValidaciones = reporte.contador_validaciones;

    // Tópico barrial basado en prefijo geohash (primeros 5 caracteres cubren ~4.9km x 4.9km)
    const geohashPrefix = reporte.geohash ? reporte.geohash.substring(0, 5) : "general";
    const topicSector = `sector_${geohashPrefix}`;
    const topicGeneral = "alertas_validadas";

    logger.info(
      `[FCM] Preparando notificación para reporte ${reporteId}. Tipo: ${reporte.tipo}, Validaciones: ${numValidaciones}`
    );

    // Estructura del mensaje FCM compatible con Android, iOS y Flutter
    const message: admin.messaging.Message = {
      topic: topicGeneral,
      notification: {
        title: `🚨 ¡ALERTA VALIDADA! (${tipoLabel})`,
        body: `Confirmada por ${numValidaciones} vecinos en tu sector. Abre CIVITAS para ver detalles en el mapa.`,
      },
      data: {
        id_reporte: String(reporteId),
        tipo: String(reporte.tipo),
        estado: "VALIDADO",
        contador_validaciones: String(numValidaciones),
        latitud: String(reporte.coordenadas?.latitude ?? 0),
        longitud: String(reporte.coordenadas?.longitude ?? 0),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "civitas_emergency_channel",
          sound: "default",
          color: "#DC2626", // AppColors.panicRed
          priority: "max",
          defaultVibrateTimings: true,
          visibility: "public",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `🚨 ¡ALERTA VALIDADA! (${tipoLabel})`,
              body: `Confirmada por ${numValidaciones} vecinos en tu sector.`,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    };

    try {
      // 1. Envío al tópico general de alertas comunitarias
      const response = await admin.messaging().send(message);
      logger.info(
        `[FCM] Notificación de validación despachada con éxito a '${topicGeneral}'. Message ID: ${response}`
      );

      // 2. Envío complementario al tópico georreferenciado por sector
      if (geohashPrefix !== "general") {
        const sectorMessage = { ...message, topic: topicSector };
        await admin.messaging().send(sectorMessage);
        logger.info(`[FCM] Notificación despachada al sector: '${topicSector}'`);
      }

      return response;
    } catch (error) {
      logger.error(`[FCM] Error crítico al enviar notificación push:`, error);
      throw error;
    }
  }
}
