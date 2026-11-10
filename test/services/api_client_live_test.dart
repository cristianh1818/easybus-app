// Prueba contra la API real (solo lecturas GET). No corre por defecto:
//   flutter test test/services/api_client_live_test.dart --dart-define=API_EN_VIVO=true
// Requiere la API levantada en API_BASE_URL (por defecto http://localhost:3000/api/v1).

import 'dart:io';

import 'package:easybus_app/config/app_config.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _enVivo = bool.fromEnvironment('API_EN_VIVO');

void main() {
  // flutter_test bloquea la red por defecto; aquí se quiere la red real.
  setUpAll(() => HttpOverrides.global = null);

  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  tearDownAll(api.close);

  test('GET /rutas responde una lista', () async {
    final rutas = await api.get('/rutas', parse: (j) => j as List);
    expect(rutas, isNotEmpty);
  }, skip: !_enVivo);

  test('Un id inválido devuelve DATOS_INVALIDOS con mensaje en español', () async {
    try {
      await api.get('/rutas/no-es-uuid', parse: (j) => j);
      fail('Se esperaba ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 400);
      expect(e.code, 'DATOS_INVALIDOS');
      expect(e.message, contains('UUID'));
    }
  }, skip: !_enVivo);

  // Todos los endpoints públicos se convierten con los modelos sin errores.
  test('EasybusApi lee la API real con los modelos', () async {
    final easybus = EasybusApi(api);
    final rutas = await easybus.rutas();
    expect(rutas, isNotEmpty);

    final detalle = await easybus.ruta(rutas.first.id);
    final embarcaderos = await easybus.embarcaderos();
    expect(embarcaderos, isNotEmpty);
    await easybus.embarcadero(embarcaderos.first.id);
    await easybus.avisos();

    for (final rs in detalle.sentidos) {
      await easybus.horarios(rutas.first.id, rs.sentido);
      final p = await easybus.proximaSalida(rutas.first.id, rs.sentido);
      expect(p.isScheduled, isTrue);
      if (rs.paradas.length > 1) {
        final intermedio = rs.paradas[1].embarcadero.id;
        final desde = await easybus.proximaSalida(rutas.first.id, rs.sentido, desdeEmbarcaderoId: intermedio);
        expect(desde.fromStop!.id, intermedio);
      }
    }
  }, skip: !_enVivo);
}
