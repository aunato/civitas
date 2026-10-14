# Cloud Functions para CIVITAS

Funciones Serverless en **TypeScript** y **Node.js 20** para la automatización comunitaria y reglas de negocio del sistema CIVITAS.

---

## ⚡ Regla de Negocio Implementada (`onReporteUpdated`)

- **Trigger:** `reportes/{reporteId}` (`onDocumentUpdated`).
- **Condición:** Si `contador_validaciones >= 5` y el estado actual no es `'VALIDADO'`.
- **Acciones:**
  1. Actualiza el documento en Cloud Firestore: `estado = 'VALIDADO'` y añade marca temporal `validado_en`.
  2. Prepara la estructura de datos compatible con **Android 13+** (canal `civitas_emergency_channel`) e **iOS**.
  3. Despacha la notificación Push mediante **Firebase Cloud Messaging (FCM)** al tópico general `alertas_validadas` y al tópico georreferenciado del sector `sector_{geohash5}`.
  4. Registra el evento en la colección de auditoría `auditoria_validaciones`.
  5. Previene bucles infinitos de escritura verificando la idempotencia del estado antes de actuar.

---

## 🚀 Despliegue en Firebase

### 1. Requisitos Previos
- Node.js versión 20.x instalado
- Firebase CLI instalado globalmente:
  ```bash
  npm install -g firebase-tools
  ```

### 2. Instalación de Dependencias y Compilación
```bash
cd functions
npm install
npm run build
```

### 3. Probar en Emulador Local
```bash
npm run serve
```

### 4. Desplegar a Producción
```bash
# Desde la raíz del proyecto
firebase deploy --only functions

# O desplegar únicamente esta función
firebase deploy --only functions:onReporteUpdated
```
