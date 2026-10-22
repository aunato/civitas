import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { ReporteDocument, TipoIncidente, UsuarioDocument } from "../types";

export class FcmService {
  /**
   * Obtiene la etiqueta amigable del tipo de incidente
   */
  public static getTipoLabel(tipo: TipoIncidente): string {
    switch (tipo) {
      case "boton_panico":
        return "BOTÓN DE PÁNICO SOS";
      case "robo_vehiculo":
        return "Robo de Vehículo / Accesorios";
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
   * Calcula la distancia en metros entre dos coordenadas geodésicas (Fórmula de Haversine)
   */
  public static calcularDistanciaMetros(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 6371e3; // Radio de la Tierra en metros
    const phi1 = (lat1 * Math.PI) / 180;
    const phi2 = (lat2 * Math.PI) / 180;
    const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
    const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
      Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return Math.round(R * c);
  }

  /**
   * Despacha una alerta instantánea por creación de incidente o botón de pánico
   * hacia tópicos sectoriales y por geofencing directo (<= 500m)
   */
  public static async despacharAlertaInmediata(
    reporteId: string,
    reporte: ReporteDocument
  ): Promise<{ messageId?: string; multicastSuccessCount: number }> {
    const esPanico = reporte.tipo === "boton_panico";
    const tipoLabel = this.getTipoLabel(reporte.tipo);
    const repLat = reporte.coordenadas?.latitude ?? 0;
    const repLng = reporte.coordenadas?.longitude ?? 0;

    const geohashPrefix = reporte.geohash ? reporte.geohash.substring(0, 5) : "general";
    const topicSector = `sector_${geohashPrefix}`;
    const topicGeneral = esPanico ? "alertas_emergencias" : "alertas_comunitarias";

    logger.info(
      `[FCM] Despachando alerta inmediata para ${reporteId}. Tipo: ${reporte.tipo}, EsPánico: ${esPanico}, Sector: ${topicSector}`
    );

    const titulo = esPanico
      ? "🚨 ¡ALERTA SOS DE PÁNICO EN TU SECTOR!"
      : `⚠️ Alerta de Seguridad: ${tipoLabel}`;

    const cuerpo = esPanico
      ? "Un vecino ha activado el botón de pánico en un radio cercano (500m). Abre CIVITAS para ver su ubicación."
      : `Nuevo incidente (${tipoLabel}) reportado cerca de tu sector. Precaución en la zona.`;

    const payloadData: Record<string, string> = {
      id_reporte: String(reporteId),
      tipo: String(reporte.tipo),
      estado: String(reporte.estado || "ACTIVO"),
      latitud: String(repLat),
      longitud: String(repLng),
      geohash: String(reporte.geohash || ""),
      es_emergencia: esPanico ? "true" : "false",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    // 1. Enviar a tópicos comunitarios para cobertura instantánea de red
    let topicMessageId: string | undefined;
    try {
      const topicMessage: admin.messaging.Message = {
        topic: topicGeneral,
        notification: {
          title: titulo,
          body: cuerpo,
        },
        data: payloadData,
        android: {
          priority: "high",
          notification: {
            channelId: esPanico ? "civitas_emergency_channel" : "civitas_alerts_channel",
            sound: "default",
            color: esPanico ? "#DC2626" : "#2563EB",
            priority: esPanico ? "max" : "high",
            defaultVibrateTimings: true,
            visibility: "public",
          },
        },
      };

      topicMessageId = await admin.messaging().send(topicMessage);
      logger.info(`[FCM] Alerta enviada a tópico '${topicGeneral}'. Message ID: ${topicMessageId}`);

      // Envío redundante al sector específico
      if (geohashPrefix !== "general") {
        await admin.messaging().send({
          ...topicMessage,
          topic: topicSector,
        });
        logger.info(`[FCM] Alerta despachada a tópico de sector: '${topicSector}'`);
      }
    } catch (err) {
      logger.error(`[FCM] Error despachando a tópicos comunitarios:`, err);
    }

    // 2. Geofencing Dinámico: Notificación dirigida a usuarios dentro del radio de 500m
    let multicastSuccessCount = 0;
    try {
      const usuariosSnap = await admin.firestore().collection("usuarios").get();
      const tokensCercanos: string[] = [];

      for (const doc of usuariosSnap.docs) {
        const data = doc.data() as UsuarioDocument;

        // Omitir al propio autor de la alerta
        if (doc.id === reporte.autor_ref || data.uid === reporte.autor_ref) {
          continue;
        }

        const token = data.fcm_token;
        if (!token) continue;

        let userLat: number | undefined;
        let userLng: number | undefined;

        if (data.ultima_ubicacion) {
          userLat = data.ultima_ubicacion.latitude;
          userLng = data.ultima_ubicacion.longitude;
        } else if (data.latitud != null && data.longitud != null) {
          userLat = Number(data.latitud);
          userLng = Number(data.longitud);
        }

        // Si tenemos ubicación, verificar radio perimetral de 500m
        if (userLat != null && userLng != null && repLat !== 0 && repLng !== 0) {
          const distancia = this.calcularDistanciaMetros(repLat, repLng, userLat, userLng);
          if (distancia <= 500) {
            tokensCercanos.push(token);
          }
        } else {
          // Si el usuario no tiene coordenadas registradas aún pero está activo, incluirlo preventivamente si es pánico
          if (esPanico) {
            tokensCercanos.push(token);
          }
        }
      }

      // Eliminar tokens duplicados
      const tokensUnicos = Array.from(new Set(tokensCercanos));

      if (tokensUnicos.length > 0) {
        logger.info(
          `[FCM-Geofence] Enviando notificación directa a ${tokensUnicos.length} vecinos en radio de 500m.`
        );

        const multicastMessage: admin.messaging.MulticastMessage = {
          tokens: tokensUnicos,
          notification: {
            title: titulo,
            body: cuerpo,
          },
          data: {
            ...payloadData,
            radio_alerta: "500m",
          },
          android: {
            priority: "high",
            notification: {
              channelId: esPanico ? "civitas_emergency_channel" : "civitas_alerts_channel",
              sound: "default",
              color: esPanico ? "#DC2626" : "#2563EB",
              priority: esPanico ? "max" : "high",
              defaultVibrateTimings: true,
            },
          },
        };

        const batchResponse = await admin.messaging().sendEachForMulticast(multicastMessage);
        multicastSuccessCount = batchResponse.successCount;
        logger.info(
          `[FCM-Geofence] Notificaciones entregadas exitosamente: ${multicastSuccessCount}/${tokensUnicos.length}`
        );
      }
    } catch (err) {
      logger.error(`[FCM-Geofence] Error en entrega georreferenciada:`, err);
    }

    return { messageId: topicMessageId, multicastSuccessCount };
  }

  /**
   * Construye y despacha las notificaciones push cuando una alerta es validada por 5 vecinos
   */
  public static async enviarNotificacionAlertaValidada(
    reporteId: string,
    reporte: ReporteDocument
  ): Promise<string> {
    const tipoLabel = this.getTipoLabel(reporte.tipo);
    const numValidaciones = reporte.contador_validaciones;

    const geohashPrefix = reporte.geohash ? reporte.geohash.substring(0, 5) : "general";
    const topicSector = `sector_${geohashPrefix}`;
    const topicGeneral = "alertas_validadas";

    logger.info(
      `[FCM] Notificación de alerta validada para ${reporteId}. Validaciones: ${numValidaciones}`
    );

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
          color: "#DC2626",
          priority: "max",
          defaultVibrateTimings: true,
          visibility: "public",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);
      logger.info(
        `[FCM] Notificación de validación despachada a '${topicGeneral}'. ID: ${response}`
      );

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
