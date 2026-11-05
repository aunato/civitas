const admin = require("firebase-admin");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Fórmula de Haversine para cálculo de distancia geodésica en metros
 */
function calcularDistanciaMetros(lat1, lon1, lat2, lon2) {
  const R = 6371e3;
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

function getTipoLabel(tipo) {
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
      return String(tipo || "alerta").replace(/_/g, " ").toUpperCase();
  }
}

/**
 * Cloud Function Trigger: onReporteCreated
 * Se ejecuta automáticamente tan pronto como un nuevo documento es insertado en 'reportes/{reporteId}'.
 * Dispara notificaciones push FCM de alta prioridad con patrones de vibración y sonido.
 */
exports.onReporteCreated = onDocumentCreated(
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
    const data = snapshot.data();
    if (!data) {
      logger.warn(`[CIVITAS-Trigger-Created] No se encontró contenido en el reporte ${reporteId}.`);
      return;
    }

    const esPanico = data.tipo === "boton_panico";
    const tipoLabel = getTipoLabel(data.tipo);
    const repLat = data.coordenadas?.latitude ?? (data.latitud ?? 0);
    const repLng = data.coordenadas?.longitude ?? (data.longitud ?? 0);
    const geohashPrefix = data.geohash ? data.geohash.substring(0, 5) : "general";

    logger.info(
      `[CIVITAS-Trigger-Created] 🔔 Nuevo reporte detectado '${reporteId}'. Tipo: ${data.tipo}, EsPánico: ${esPanico}`
    );

    const titulo = esPanico
      ? "🚨 ¡ALERTA SOS DE PÁNICO EN TU SECTOR!"
      : `⚠️ Alerta de Seguridad: ${tipoLabel}`;

    const cuerpo = esPanico
      ? "Un vecino ha activado el botón de pánico en un radio cercano (500m). Abre CIVITAS para ver su ubicación."
      : `Nuevo incidente (${tipoLabel}) reportado cerca de tu sector. Precaución en la zona.`;

    const payloadData = {
      id_reporte: String(reporteId),
      tipo: String(data.tipo || "actividad_sospechosa"),
      estado: String(data.estado || "ACTIVO"),
      latitud: String(repLat),
      longitud: String(repLng),
      geohash: String(data.geohash || ""),
      es_emergencia: esPanico ? "true" : "false",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    // Configuración de Alta Prioridad FCM con Patrón de Vibración y Sonido
    const androidConfig = {
      priority: "high",
      notification: {
        channelId: esPanico ? "civitas_emergency_channel" : "civitas_alerts_channel",
        sound: "default",
        defaultSound: true,
        color: esPanico ? "#DC2626" : "#2563EB",
        priority: "max",
        defaultVibrateTimings: false,
        vibrateTimingsMillis: esPanico
          ? [0, 500, 200, 500, 200, 1000] // Patrón SOS urgente: vibra-pausa-vibra
          : [0, 300, 150, 300],          // Patrón preventivo
        visibility: "public",
        lightSettings: {
          color: esPanico ? "#DC2626" : "#2563EB",
          lightOnDurationMillis: 500,
          lightOffDurationMillis: 500,
        },
      },
    };

    const apnsConfig = {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          contentAvailable: true,
          critical: esPanico ? 1 : 0,
        },
      },
    };

    let multicastSuccessCount = 0;

    // 1. Envío a Tópicos Comunitarios
    try {
      const topicGeneral = esPanico ? "alertas_emergencias" : "alertas_comunitarias";
      await admin.messaging().send({
        topic: topicGeneral,
        notification: { title: titulo, body: cuerpo },
        data: payloadData,
        android: androidConfig,
        apns: apnsConfig,
      });

      if (geohashPrefix !== "general") {
        await admin.messaging().send({
          topic: `sector_${geohashPrefix}`,
          notification: { title: titulo, body: cuerpo },
          data: payloadData,
          android: androidConfig,
          apns: apnsConfig,
        });
      }
    } catch (err) {
      logger.error("[CIVITAS-Trigger-Created] Error enviando a tópicos:", err);
    }

    // 2. Geofencing Directo (<= 500m)
    try {
      const usuariosSnap = await admin.firestore().collection("usuarios").get();
      const tokensCercanos = [];

      for (const doc of usuariosSnap.docs) {
        const uData = doc.data();
        if (doc.id === data.autor_ref || uData.uid === data.autor_ref) continue;
        if (!uData.fcm_token) continue;

        let userLat = uData.ultima_ubicacion?.latitude ?? uData.latitud;
        let userLng = uData.ultima_ubicacion?.longitude ?? uData.longitud;

        if (userLat != null && userLng != null && repLat !== 0 && repLng !== 0) {
          const dist = calcularDistanciaMetros(repLat, repLng, Number(userLat), Number(userLng));
          if (dist <= 500) {
            tokensCercanos.push(uData.fcm_token);
          }
        } else if (esPanico) {
          tokensCercanos.push(uData.fcm_token);
        }
      }

      const tokensUnicos = Array.from(new Set(tokensCercanos));
      if (tokensUnicos.length > 0) {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokensUnicos,
          notification: { title: titulo, body: cuerpo },
          data: { ...payloadData, radio_alerta: "500m" },
          android: androidConfig,
          apns: apnsConfig,
        });
        multicastSuccessCount = response.successCount;
        logger.info(
          `[CIVITAS-Trigger-Created] Notificaciones push entregadas a ${multicastSuccessCount}/${tokensUnicos.length} vecinos en radio 500m.`
        );
      }
    } catch (err) {
      logger.error("[CIVITAS-Trigger-Created] Error en geofencing:", err);
    }

    // 3. Registrar auditoría y actualizar reporte
    try {
      await snapshot.ref.update({
        notificado_fcm: true,
        notificado_en: admin.firestore.FieldValue.serverTimestamp(),
        fcm_multicast_count: multicastSuccessCount,
      });

      await admin.firestore().collection("auditoria_alertas").add({
        id_reporte: reporteId,
        tipo: data.tipo,
        autor_ref: data.autor_ref,
        multicast_count: multicastSuccessCount,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.warn("[CIVITAS-Trigger-Created] Advertencia al actualizar bitácora:", err);
    }
  }
);

/**
 * Cloud Function Trigger: onReporteUpdated
 * Verifica el umbral comunitario (>= 5 confirmaciones) para cambiar estado a VALIDADO y despachar FCM.
 */
exports.onReporteUpdated = onDocumentUpdated(
  {
    document: "reportes/{reporteId}",
    region: "us-central1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const change = event.data;
    if (!change) return;

    const reporteId = event.params.reporteId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    if (!afterData) return;

    const beforeContador = beforeData?.contador_validaciones ?? 0;
    const afterContador = afterData?.contador_validaciones ?? 0;
    const beforeEstado = beforeData?.estado ?? "ACTIVO";
    const afterEstado = afterData?.estado ?? "ACTIVO";

    // Idempotencia
    if (beforeEstado === "VALIDADO" && afterEstado === "VALIDADO") return;
    if (afterContador < 5) return;

    if (afterContador >= 5 && afterEstado !== "VALIDADO") {
      logger.info(
        `[CIVITAS-Trigger-Updated] 🎯 Umbral alcanzado para ${reporteId} (${afterContador} confirmaciones). Cambiando a VALIDADO.`
      );

      await change.after.ref.update({
        estado: "VALIDADO",
        validado_en: admin.firestore.FieldValue.serverTimestamp(),
        notificado_fcm: true,
      });

      const tipoLabel = getTipoLabel(afterData.tipo);
      await admin.messaging().send({
        topic: "alertas_validadas",
        notification: {
          title: `🚨 ¡ALERTA VALIDADA! (${tipoLabel})`,
          body: `Confirmada por ${afterContador} vecinos en tu sector. Revisa los detalles en CIVITAS.`,
        },
        data: {
          id_reporte: String(reporteId),
          tipo: String(afterData.tipo),
          estado: "VALIDADO",
          contador_validaciones: String(afterContador),
          latitud: String(afterData.coordenadas?.latitude ?? 0),
          longitud: String(afterData.coordenadas?.longitude ?? 0),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "civitas_emergency_channel",
            sound: "default",
            defaultSound: true,
            color: "#DC2626",
            priority: "max",
            defaultVibrateTimings: false,
            vibrateTimingsMillis: [0, 400, 200, 400],
            visibility: "public",
          },
        },
      });

      await admin.firestore().collection("auditoria_validaciones").add({
        id_reporte: reporteId,
        tipo: afterData.tipo,
        validaciones_finales: afterContador,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);
