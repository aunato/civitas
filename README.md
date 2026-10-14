# CIVITAS - Aplicación Móvil de Seguridad Ciudadana

CIVITAS es una plataforma comunitaria de alerta temprana y seguridad colaborativa orientada a reducir la "Cifra Negra" del delito mediante reporte rápido, mapas en tiempo real y validación barrial bajo **Clean Architecture**.

---

## 🏛 Arquitectura del Sistema (Clean Architecture / Feature-First)

El proyecto está organizado en capas desacopladas que garantizan mantenibilidad, testabilidad y aislamiento del framework:

```text
lib/
├── core/
│   ├── constants/       # Colores, colecciones Firebase y reglas de negocio (500m, validaciones)
│   ├── errors/          # Fallos de dominio (Failures) y excepciones de infraestructura (Exceptions)
│   ├── services/        # FirebaseService (Init asíncrono), LocationService (GPS), NotificationService (FCM)
│   ├── theme/           # Tema Material 3 optimizado para alta visibilidad y alertas
│   └── utils/           # Fórmulas geodésicas (Haversine) y formateadores
├── features/
│   ├── auth/            # Módulo de Autenticación e Identidad
│   │   ├── data/        # DataSources (FirebaseAuth + Firestore), Modelos y Repositorios Impl
│   │   ├── domain/      # Entidades (UserEntity), Contratos de Repositorio y Casos de Uso
│   │   └── presentation/# Pantallas (LoginScreen) y componentes visuales
│   ├── reportes/        # Módulo Central de Alertas y Botón de Pánico
│   │   ├── data/        # Firestore 'reportes', gestión de transacciones y estados
│   │   ├── domain/      # ReporteEntity, Casos de Uso (Crear, Disparar Pánico <3s, Validar)
│   │   └── presentation/# Mapa interactivo (Google Maps), Botón de Pánico y tarjetas
│   └── home/            # Dashboard y navegación del ciudadano
├── app.dart             # Configuración principal de MaterialApp y temas
└── main.dart            # Inicialización asíncrona de Firebase Core y FCM
```

---

## 📦 Matriz de Dependencias (Compatibilidad Verificada)

| Paquete | Versión | Rol Arquitectónico |
| :--- | :--- | :--- |
| `firebase_core` | `^3.8.1` | Inicialización del entorno Firebase BoM |
| `firebase_auth` | `^5.3.3` | Gestión de identidad de vecinos y dirigentes |
| `cloud_firestore` | `^5.5.1` | Persistencia en tiempo real y soporte offline de reportes |
| `firebase_messaging` | `^15.1.6` | Alertas tempranas Push comunitarias (Android 13+ y Background) |
| `google_maps_flutter`| `^2.10.0`| Visualización territorial interactiva de delitos |
| `geolocator` | `^13.0.2`| Captura precisa GPS y verificación de radio de 500m |

---

## 🚀 Puesta en Marcha y Compilación en Android

### 1. Requisitos Previos
- Flutter SDK (versión 3.19 o superior)
- Android Studio / Android SDK (API 34)

### 2. Configurar Firebase y Google Maps
1. **Google Maps**:
   - Abra `android/app/src/main/AndroidManifest.xml`.
   - Reemplace `REEMPLAZAR_CON_TU_GOOGLE_MAPS_API_KEY` por su clave de API de Google Cloud Console con el SDK de Maps habilitado.
2. **Firebase**:
   - Reemplace `android/app/google-services.json` con el archivo descargado de su consola de Firebase Console.

### 3. Comandos de Ejecución
```bash
# Obtener paquetes
flutter pub get

# Ejecutar en emulador o dispositivo físico
flutter run

# Generar APK para producción
flutter build apk --release
```
