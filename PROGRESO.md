# Progreso de EASYBUS (fase 1: fluvial)

Última actualización: 2026-11-26 (tareas 1 a 8 de la entrega final).

## App (`easybus_app`)

| Commit | Contenido |
|---|---|
| `69d3b67` | Paso 1: proyecto Flutter y estructura de carpetas |
| `478e1d5` | Paso 2: tema con Poppins incluida |
| `4473ab7` | Paso 3: config de la API (`API_BASE_URL`) y ApiClient con dio |
| `be16da1` | Paso 4: modelos de la API y endpoints con tipos |
| `6dd6dcc` | Paso 5: repository, splash con el logo oficial e ícono de la app |
| `bb5fad1` | Paso 6: barra inferior, menú lateral y Configuración |
| `6c7182b` | Paso 7: pantalla de Embarcaderos y arreglos de diseño |
| `4ba169b` | Paso 8: caché offline con drift/SQLite |
| `36abe7d` | CLAUDE.md con la forma de trabajar |
| `dbb8bda` | Próxima salida sin conexión y mensajes de error; detalle del embarcadero; arreglo de conexiones inactivas y reintento de GET |
| `e0c4fe6` | Mapa del río (parte 1): embarcaderos, chips de rutas, sentido y hoja del embarcadero |
| `846234d` | Foto del embarcadero en el detalle, con caché (`cached_network_image`) |
| `0be8b6f` | PROGRESO.md con los datos nuevos de BS-1 |
| `2e61e0a` | Mapa del río (parte 2): mi ubicación y los 3 embarcaderos más cercanos (calculado en el teléfono) |
| `40c361b` | PROGRESO.md: tiempos de BS-1 a 20 km/h + 1 min por parada |
| `f44604e` | Tarea 1 · Ajustes: foto con Hero y zoom, barra del sistema, un solo ☰, caché y actualizar |
| `9a969e0` | Tarea 2 · Detalle de la ruta: línea del río, sentido, horas de paso y horarios |
| `6253b58` | Tarea 3 · Mapa (parte 3): "¿A dónde quieres ir hoy?" con propuesta de viaje |
| `c1af56b` | Tarea 4 · Cuenta del pasajero: sesión, favoritos y últimas consultas |
| `4028a67` | Tarea 5 · Pulido: actualizar con onda de agua y pulso del zarpe a 5 min o menos |

## Backend (`easybus-backend`)

| Commit | Contenido |
|---|---|
| `a8fbeae` | CLAUDE.md con la forma de trabajar |
| `a2a609a` | Endpoint público `GET /api/v1/festivos?anio=` |
| `437e836` | Panel: editor de trazado (arrastrar, curvas, borrar, deshacer, copiar el otro sentido, km) |
| `ca6e01e` | Fotos de embarcaderos: subida desde el panel, WEBP sin EXIF, en `/uploads` |
| `0b60a47` | Seed con los datos nuevos: BS-1 "Businú", 11 embarcaderos, 4 embarcaciones (sin BS-2) |
| `9905a07` | Tiempos estimados a 20 km/h + 1 min por parada; 5 embarcaciones en el seed |
| `f21275c` | Tarea 6 · Favoritos del pasajero: GET, POST y DELETE `/usuarios/me/favoritos` |
| `7db4896` | Tarea 6 · README: guion de la demo de la entrega final (panel + app, 10 min) |
| `807db31` | Tarea 7 · Despliegue en Azure: Dockerfile, `docker-compose.prod.yml` (API, PostGIS, Caddy con HTTPS, respaldo diario 7 días), `.env.production.example`, scripts para migrar la base y las fotos, `DESPLIEGUE.md` |

Todo en la rama `entrega-final` de los dos repos (sin merge a `main`).

## Servidor en Azure (tarea 7): preparado, falta ejecutarlo

Los archivos y la guía están listos, pero **todavía no se ha desplegado** (no se entró a
la VM). Seguir `DESPLIEGUE.md` del backend, pasos 1 a 10. Quedará en:

- API: `https://easybus-unicordoba.northcentralus.cloudapp.azure.com/api/v1`
- Panel: `https://easybus-unicordoba.northcentralus.cloudapp.azure.com/panel`

Se ensayó todo el conjunto en el computador (Docker local, proyecto aparte y luego
borrado): construcción de la imagen, HTTPS con Caddy, `/` → `/panel/`, HTTP → HTTPS,
Swagger apagado (404), restauración de la base y las 11 fotos con los scripts, y el
respaldo (`pg_dump` + fotos). Lo único que no se pudo ensayar es el certificado real de
Let's Encrypt, que solo se obtiene en la VM.

### APK que usa el servidor

La app **no** agrega `/api/v1` sola: `API_BASE_URL` debe terminar en `/api/v1`. En
release solo acepta HTTPS (`lib/config/app_config.dart`).

```powershell
# APK de release apuntando al servidor de Azure
flutter build apk --release --dart-define=API_BASE_URL=https://easybus-unicordoba.northcentralus.cloudapp.azure.com/api/v1
# Queda en build\app\outputs\flutter-apk\app-release.apk

# O probar en el celular por USB contra el servidor (sin adb reverse)
flutter run --dart-define=API_BASE_URL=https://easybus-unicordoba.northcentralus.cloudapp.azure.com/api/v1
```

Antes, comprobar que
`https://easybus-unicordoba.northcentralus.cloudapp.azure.com/api/v1/health` responde `ok`.

### APK de debug (tarea 8)

- Compilada el 2026-11-26 con `flutter build apk --debug` (sin `--dart-define`).
- Archivo: `C:\Users\HP\Desktop\easybus_app\build\app\outputs\flutter-apk\app-debug.apk`
  (≈ 197 MB; no está en Git).
- Usa la API local `http://localhost:3000/api/v1`: en el celular hace falta
  `adb reverse tcp:3000 tcp:3000` y la API corriendo en el computador. Para una APK que
  use el servidor de Azure, compilar la de release de arriba.
- Instalar: `adb install -r build\app\outputs\flutter-apk\app-debug.apk`.

## Decisiones

- Mapa: `flutter_map` con teselas estándar de OpenStreetMap (`tile.openstreetmap.org`),
  las mismas del panel, sin clave. Cumple su política: User-Agent propio
  (`userAgentPackageName`), atribución "© OpenStreetMap" visible y caché de teselas.
  Se descartó CARTO (Voyager) porque sus teselas exigen API key (en el celular salía
  "API KEY REQUIRED"). El proveedor está en un solo lugar (`lib/config/map_config.dart`
  y `lib/widgets/map/eb_river_map.dart`) para poder cambiar a Google Maps más adelante.

## Datos actuales (no oficiales, cargados desde el panel)

- Una sola ruta: BS-1 "Businú", Embarcadero Sierra Chiquita (sur) ↔ Embarcadero Boca
  de la Ceiba (norte), 11 embarcaderos, trazado de 16,97 km (la vuelta es la ida al
  revés). 5 embarcaciones (BN-01 a BN-05). Salidas cada 30 min: lunes a viernes
  05:30–22:00; sábados, domingos y festivos 05:30–19:00. BS-2 se eliminó.
- `npm run seed:reset` ya carga estos mismos datos (sin las fotos, que no están en Git).

### Tiempos de BS-1: ESTIMACIÓN pendiente de medir en un viaje real

Regla desde el 2026-11-26: **20 km/h por el trazado + 1 minuto por cada parada
intermedia** (antes 10 min/km). En una parada intermedia el tiempo es la hora en que la
embarcación sale de ahí; en el destino, la de llegada. Los 11 embarcaderos están sobre
el trazado (0 m) y las reglas A y B coinciden (verificado solo lectura).

| # | Embarcadero | km desde Sierra Chiquita | Ida (min) | Vuelta (min) |
|---|---|---|---|---|
| 1 | Sierra Chiquita | 0,00 | 0 | 60 |
| 2 | Batallón | 3,00 | 10 | 51 |
| 3 | Sur | 4,31 | 15 | 46 |
| 4 | Puente Metálico | 5,45 | 19 | 42 |
| 5 | Avenida primera | 6,31 | 23 | 38 |
| 6 | María Varilla | 7,19 | 27 | 34 |
| 7 | Sucre | 8,32 | 31 | 30 |
| 8 | Ronda Norte | 10,06 | 37 | 24 |
| 9 | Club campestre | 11,28 | 42 | 19 |
| 10 | Universidad de Córdoba | 12,71 | 47 | 14 |
| 11 | Boca de la Ceiba | 16,97 | 60 | 0 |

Flota: ida + vuelta + unos 10 min de espera ≈ 130 min; con una salida cada 30 min
desde cada extremo hacen falta 5 embarcaciones (antes, con 170 min por viaje, unas 12).
Cuando se mida un viaje real, escribir esos minutos en el panel (quedan como "real" y los
estimados siguientes parten de ellos) o ajustar `VELOCIDAD_KMH` / `MINUTOS_POR_PARADA`
en `src/rutas/tiempos-estimados.ts`.

## Qué probar

1. **APK de debug** en el celular (`adb install -r ...app-debug.apk`,
   `adb reverse tcp:3000 tcp:3000`, API local encendida): Embarcaderos, detalle con foto
   (Hero y zoom), detalle de la ruta, Mapa con "¿A dónde quieres ir hoy?", Cuenta (crear
   cuenta, favoritos, últimas consultas), deslizar para actualizar (gota de agua) y el
   pulso del chip cuando faltan 5 min o menos. Crear cuentas y favoritos escribe en la
   base: no hacerlo contra la base real local `easybus`; usar la base de prueba o, ya
   desplegado, el servidor.
2. **Despliegue**: seguir `DESPLIEGUE.md`; al final, `/api/v1/health` ok, el panel con
   candado válido y las fotos de los embarcaderos visibles.
3. **APK de release** contra el servidor (ver arriba).

## Pendientes

### Backend / datos (desde el panel, para que quede en la auditoría)
- Medir un viaje real de BS-1 y registrar esos minutos en el panel (los de hoy son una
  estimación a 20 km/h + 1 min por parada).
- Mayúsculas en el panel: destinos "Embarcadero Boca de la ceiba" y "Embarcadero Sierra
  chiquita" (los nombres de los embarcaderos sí van con mayúscula).
- Cargar los festivos de 2027: `GET /festivos?anio=2027` está vacío. Sin ellos, desde el
  1 de enero el backend y la app aplicarán horario laboral en los festivos.

### Despliegue
- Ejecutar `DESPLIEGUE.md` en la VM (pasos 1 a 10), incluida la migración de datos
  (paso 9).
- Compilar la APK de release con el servidor y probarla en el celular con datos móviles.
- Crear un presupuesto con alerta en Azure (Administración de costos) y decidir si se
  usa el apagado automático de la VM.
- Unir `entrega-final` a `main` cuando el equipo lo apruebe (no se hizo merge).

### App
- "Continuar con Google", Notificaciones y Viaje seguro siguen como "Próximamente".
- Logo en 1024 px o SVG del equipo: ya se usa el SVG oficial; revisar si hay versión más
  reciente.
