# EASYBUS · app móvil

App Flutter de EASYBUS. Fase 1: transporte fluvial Businú en los embarcaderos del
río Sinú (Montería). Consume la API de [easybus-backend](https://github.com/cristianh1818/easybus-backend)
(`/api/v1`).

## Correr en desarrollo

La URL de la API se pasa al compilar con `--dart-define=API_BASE_URL=...`.

| Dónde | Comando |
|---|---|
| Teléfono por USB | `adb reverse tcp:3000 tcp:3000` y luego `flutter run` (usa `http://localhost:3000/api/v1` por defecto) |
| Emulador Android | `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1` |
| Release | `flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define=API_BASE_URL=https://.../api/v1` (solo HTTPS) |

En VS Code están las mismas opciones en *Ejecutar y depurar* (`.vscode/launch.json`).
`adb reverse` se pierde al desconectar el cable: hay que repetirlo.

## Pruebas

```
flutter analyze
flutter test
# Contra la API real (solo lecturas; la API debe estar levantada):
flutter test test/services/api_client_live_test.dart --dart-define=API_EN_VIVO=true
```

## Estructura

```
lib/
  config/     URL base de la API (--dart-define)
  theme/      tokens Eb*, tema con Poppins, estilo por modo, márgenes del sistema
  models/     TransportMode y modelos de la API (fromJson a mano)
  services/   ApiClient (dio) y ApiException
  providers/  Riverpod
  screens/    pantallas
  widgets/    componentes Eb*
```

## Reglas

- Privacidad (RNF-07): el "cerca de mí" se calcula en el teléfono; la ubicación
  del usuario nunca se envía al servidor.
- Cada pantalla respeta las barras del sistema (`ebScrollPadding` o `SafeArea`) y se
  prueba con la fuente al 100, 130 y 200 % (`test/helpers/layout_checks.dart`).
- Poppins va incluida en la app (licencia OFL en `assets/fonts/OFL.txt`).
