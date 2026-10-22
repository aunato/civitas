import * as admin from "firebase-admin";

// Inicializar Firebase Admin SDK una sola vez para toda la instancia de Cloud Functions
if (!admin.apps.length) {
  admin.initializeApp();
}

// Exportar triggers de Cloud Functions
export { onReporteCreated } from "./triggers/onReporteCreated";
export { onReporteUpdated } from "./triggers/onReporteUpdated";
