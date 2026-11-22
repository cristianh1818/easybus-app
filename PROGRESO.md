# Progreso de EASYBUS (fase 1: fluvial)

Última actualización: 2026-11-22.

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

## Backend (`easybus-backend`)

| Commit | Contenido |
|---|---|
| `a8fbeae` | CLAUDE.md con la forma de trabajar |
| `a2a609a` | Endpoint público `GET /api/v1/festivos?anio=` |

## Pendientes

### Backend / datos (desde el panel, para que quede en la auditoría)
- Renombrar "Embarcadero Corrección" (referencia: "Cerca al puente vehicular sobre el
  río"). Ojo: ya existe "Embarcadero Puente Metálico" a ~650 m; usar un nombre que no
  se confunda (p. ej. "Puente vehicular").
- Corregir los trazados de ida y vuelta de BS-1 (paso "C") y luego verificar, solo
  lectura, la tabla de minutos (regla A vs. B). Hoy "Embarcadero Sur" está a 1442 m del
  trazado de vuelta.
- Cargar los festivos de 2027: `GET /festivos?anio=2027` está vacío. Sin ellos, desde el
  1 de enero el backend y la app aplicarán horario laboral en los festivos.

### App
- Mapa real del río (pestaña Mapa) y "cerca de mí" calculado en el teléfono (con
  permiso de ubicación).
- Detalle de la ruta con la línea del río (pantalla insignia).
- Búsqueda de origen y destino (píldora "¿A dónde quieres ir hoy?"; hoy lleva a
  Embarcaderos).
- Cuenta: inicio de sesión opcional, favoritos y últimas consultas.
- Pulido de easybus-motion pendiente: indicador de actualizar con onda de agua y pulso
  del chip cuando faltan 5 minutos o menos.
- Logo en 1024 px o SVG del equipo: ya se usa el SVG oficial; revisar si hay versión más
  reciente.
