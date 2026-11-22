# EASYBUS · app móvil (Flutter)

App del pasajero para el transporte fluvial Businú (embarcaderos del río Sinú, Montería).
API: repo `easybus-backend` (`/api/v1`). Textos y explicaciones en español.

## Forma de trabajar (reglas del usuario)

- Prioridad: terminar la funcionalidad para que el usuario la pruebe en el celular.
- Pruebas solo para lógica importante (cálculo de próxima salida, tipo de día, festivos,
  caché) y para los errores que se corrijan. Máximo 1 a 3 pruebas nuevas por tarea.
- No hacer auditorías de diseño, capturas ni pruebas de fuente al 100/130/200 % en cada
  paso: el usuario revisa el diseño en el celular y avisa si algo se ve mal.
- Ejecutar solo las pruebas del archivo cambiado. La suite completa, una sola vez antes
  del commit.
- No compilar el APK salvo que se agregue un paquete nuevo (el usuario prueba con
  `flutter run`).
- Si una prueba falla 2 veces seguidas: detenerse y explicar, no seguir intentando.
- Para diagnosticar errores de la API, usar llamadas directas (curl), no pruebas.
- Explicar los cambios y esperar confirmación antes de commit/push.

## Datos

- Pruebas contra la API real (puerto 3000) solo con GET. Nada que cree, modifique o
  borre datos reales (la tabla de auditoría debe tener solo cambios del administrador).

## Comandos

- Correr en el teléfono por USB: `adb reverse tcp:3000 tcp:3000` y `flutter run`.
- Un archivo de pruebas: `flutter test --no-pub test/ruta/al_test.dart`.
- Código generado (drift): `dart run build_runner build --delete-conflicting-outputs`.
- Imágenes de marca: `flutter test tool/generate_brand_images_test.dart`.
