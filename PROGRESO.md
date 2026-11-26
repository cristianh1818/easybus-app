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
| `0be8b6f` | PROGRESO.md con los datos nuevos de BS-1 |
| `2e61e0a` | Mapa del río (parte 2): mi ubicación y los 3 embarcaderos más cercanos (calculado en el teléfono) |

## Backend (`easybus-backend`)

| Commit | Contenido |
|---|---|
| `a8fbeae` | CLAUDE.md con la forma de trabajar |
| `a2a609a` | Endpoint público `GET /api/v1/festivos?anio=` |
| `437e836` | Panel: editor de trazado (arrastrar, curvas, borrar, deshacer, copiar el otro sentido, km) |
| `ca6e01e` | Fotos de embarcaderos: subida desde el panel, WEBP sin EXIF, en `/uploads` |
| `0b60a47` | Seed con los datos nuevos: BS-1 "Businú", 11 embarcaderos, 4 embarcaciones (sin BS-2) |
| `9905a07` | Tiempos estimados a 20 km/h + 1 min por parada; 5 embarcaciones en el seed |

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

## Pendientes

### Backend / datos (desde el panel, para que quede en la auditoría)
- Medir un viaje real de BS-1 y registrar esos minutos en el panel (los de hoy son una
  estimación a 20 km/h + 1 min por parada).
- Mayúsculas en el panel: destinos "Embarcadero Boca de la ceiba" y "Embarcadero Sierra
  chiquita" (los nombres de los embarcaderos sí van con mayúscula).
- Cargar los festivos de 2027: `GET /festivos?anio=2027` está vacío. Sin ellos, desde el
  1 de enero el backend y la app aplicarán horario laboral en los festivos.

### App
- Detalle de la ruta con la línea del río (pantalla insignia).
- Búsqueda de origen y destino (píldora "¿A dónde quieres ir hoy?"; hoy lleva a
  Embarcaderos).
- Cuenta: inicio de sesión opcional, favoritos y últimas consultas.
- Pulido de easybus-motion pendiente: indicador de actualizar con onda de agua y pulso
  del chip cuando faltan 5 minutos o menos.
- Logo en 1024 px o SVG del equipo: ya se usa el SVG oficial; revisar si hay versión más
  reciente.
