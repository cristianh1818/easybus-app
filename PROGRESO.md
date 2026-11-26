# Progreso de EASYBUS (fase 1: fluvial)

Última actualización: 2026-11-26.

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

## Backend (`easybus-backend`)

| Commit | Contenido |
|---|---|
| `a8fbeae` | CLAUDE.md con la forma de trabajar |
| `a2a609a` | Endpoint público `GET /api/v1/festivos?anio=` |
| `437e836` | Panel: editor de trazado (arrastrar, curvas, borrar, deshacer, copiar el otro sentido, km) |
| `ca6e01e` | Fotos de embarcaderos: subida desde el panel, WEBP sin EXIF, en `/uploads` |
| `0b60a47` | Seed con los datos nuevos: BS-1 "Businú", 11 embarcaderos, 4 embarcaciones (sin BS-2) |

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
  revés). 4 embarcaciones (BN-01 a BN-04). Salidas cada 30 min: lunes a viernes
  05:30–22:00; sábados, domingos y festivos 05:30–19:00. BS-2 se eliminó.
- `npm run seed:reset` ya carga estos mismos datos (sin las fotos, que no están en Git).

### Tabla de minutos de BS-1 (verificada el 2026-11-26, solo lectura)

Los 11 embarcaderos están sobre el trazado (0 m) y la regla A (solo trazado) coincide
con la regla B (el mayor entre trazado y línea recta) en todos. Con 10 min/km:

| # | Embarcadero | km desde Sierra Chiquita | Ida (min) | Vuelta (min) |
|---|---|---|---|---|
| 1 | Sierra Chiquita | 0,00 | 0 | 170 |
| 2 | Batallón | 3,00 | 30 | 140 |
| 3 | Sur | 4,31 | 43 | 127 |
| 4 | Puente Metálico | 5,45 | 54 | 115 |
| 5 | Avenida primera | 6,31 | 63 | 107 |
| 6 | María Varilla | 7,19 | 72 | 98 |
| 7 | Sucre | 8,32 | 83 | 86 |
| 8 | Ronda Norte | 10,06 | 101 | 69 |
| 9 | Club campestre | 11,28 | 113 | 57 |
| 10 | Universidad de Córdoba | 12,71 | 127 | 43 |
| 11 | Boca de la Ceiba | 16,97 | 170 | 0 |

Son coherentes con la distancia, pero 10 min/km (6 km/h) es lento para una lancha: un
viaje dura 170 min y, con salidas cada 30 min en ambos extremos, harían falta unas 12
embarcaciones (hay 4). Propuesta pendiente de decidir: 20 km/h + 1 min por parada
(unos 60 min por sentido).

## Pendientes

### Backend / datos (desde el panel, para que quede en la auditoría)
- Decidir la velocidad de BS-1 (hoy 10 min/km) o escribir los minutos reales de un
  viaje medido en el panel (quedan como "real" y los estimados siguientes parten de ahí).
- Mayúsculas en el panel: destinos "Embarcadero Boca de la ceiba" y "Embarcadero Sierra
  chiquita" (los nombres de los embarcaderos sí van con mayúscula).
- Cargar los festivos de 2027: `GET /festivos?anio=2027` está vacío. Sin ellos, desde el
  1 de enero el backend y la app aplicarán horario laboral en los festivos.

### App
- Mapa del río, parte 2: mi ubicación y embarcaderos más cercanos (en curso).
- Detalle de la ruta con la línea del río (pantalla insignia).
- Búsqueda de origen y destino (píldora "¿A dónde quieres ir hoy?"; hoy lleva a
  Embarcaderos).
- Cuenta: inicio de sesión opcional, favoritos y últimas consultas.
- Pulido de easybus-motion pendiente: indicador de actualizar con onda de agua y pulso
  del chip cuando faltan 5 minutos o menos.
- Logo en 1024 px o SVG del equipo: ya se usa el SVG oficial; revisar si hay versión más
  reciente.
