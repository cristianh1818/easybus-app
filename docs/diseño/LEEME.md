# Recursos de diseño EASYBUS

Carpeta del repo: `easybus_app/docs/diseño/`.

## logo/
- `easybus_logo.svg`: **logo oficial vectorial (fuente única)**. Es vectorial de verdad (trazos,
  sin imágenes incrustadas) y el texto "EASYBUS" está en trazos. El splash, el logo de la app y
  los íconos se generan desde aquí con `flutter test tool/generate_brand_images_test.dart`.
  Azul del cuadro en el SVG: `#07295B`; la app usa `#08295C` (`EbColors.logoBlue`, 1/255 de diferencia).
- `easybus_logo_500.png`: versión anterior en PNG (500×500 px), extraída del mockup "Pantalla de carga".

## mockups/
Los 13 mockups del proyecto en PNG (los PDF no se suben al repo):
- `Pantalla_de_carga`: splash. Fondo `#455F84` con el logo centrado.
- `Pantalla_principal` / `Frame_14`: mapa con botón de menú (☰), píldora "¿A dónde quieres ir hoy?" y barra inferior.
- `Menu_despegable`: menú lateral (Centro de ayuda, Notificaciones, Viaje seguro, Compartir, Configuración, Acerca de) con el logo abajo.
- `A_donde_quieres_ir`: buscador origen/destino + "Rutas disponibles" con "Siguiente salida".
- `Rutas`, `Ruta_P1`, `Ruta_D1`, `Ruta_V1`, `Ruta_D1-1`: lista de rutas con horarios y detalle de ruta en el mapa.
- `Inicio_de_sesion`: pantalla Cuenta.
- `Line_1`, `money-square`: recursos sueltos (línea e ícono).

## Ojo: los mockups son de buses
Los mockups se hicieron para buses (P1, D1, V1). En la fase 1 (fluvial) se toma de ellos
**la estructura y el estilo** (barra inferior, píldora de búsqueda, menú lateral, tarjetas),
cambiando rutas de bus por **embarcaderos y la ruta fluvial**.

Fuera de la beta (no implementar, o "Próximamente"): Viaje seguro, Centro de notificaciones,
Gastos mensuales, inicio con Facebook.
