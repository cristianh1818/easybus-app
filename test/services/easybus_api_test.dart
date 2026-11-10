import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde con un fixture según la ruta pedida y guarda la última URL.
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.files);

  final Map<String, (String file, int status)> files;
  Uri? lastUri;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    lastUri = o.uri;
    final match = files.entries.firstWhere((e) => o.uri.path.endsWith(e.key),
        orElse: () => throw StateError('Sin fixture para ${o.uri.path}'));
    final (file, status) = match.value;
    return ResponseBody.fromString(File('test/fixtures/$file').readAsStringSync(), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

(EasybusApi, _FixtureAdapter) _api(Map<String, (String, int)> files) {
  final adapter = _FixtureAdapter(files);
  final client = ApiClient(baseUrl: 'http://localhost:3000/api/v1', dio: Dio()..httpClientAdapter = adapter);
  return (EasybusApi(client), adapter);
}

void main() {
  test('rutas()', () async {
    final (api, a) = _api({'/rutas': ('rutas.json', 200)});
    final rutas = await api.rutas();
    expect(rutas.single.codigo, 'BS-1');
    expect(a.lastUri.toString(), 'http://localhost:3000/api/v1/rutas');
  });

  test('proximaSalida() envía sentido y desde, y omite momento si es null', () async {
    final (api, a) = _api({'/proxima-salida': ('proxima_salida_no_more.json', 200)});
    final p = await api.proximaSalida('r-1', Sentido.ida, desdeEmbarcaderoId: 'e-2');
    expect(p.status, DepartureStatus.noMoreDeparturesToday);
    expect(a.lastUri!.path, '/api/v1/rutas/r-1/proxima-salida');
    expect(a.lastUri!.queryParameters, {'sentido': 'ida', 'desde': 'e-2'});
  });

  test('horarios() con tipo de día', () async {
    final (api, a) = _api({'/horarios': ('horarios.json', 200)});
    await api.horarios('r-1', Sentido.vuelta, tipoDia: TipoDia.domingoFestivo);
    expect(a.lastUri!.queryParameters, {'sentido': 'vuelta', 'tipoDia': 'domingo_festivo'});
  });

  test('Un id con "/" no puede cambiar la ruta de la URL', () async {
    final (api, a) = _api({'/embarcaderos/..%2Fadmin': ('embarcadero_detalle.json', 200)});
    await api.embarcadero('../admin');
    expect(a.lastUri!.path, '/api/v1/embarcaderos/..%2Fadmin');
  });

  test('Error real de la API: EMBARCADERO_FUERA_DE_RUTA', () async {
    final (api, _) = _api({'/proxima-salida': ('error_fuera_de_ruta.json', 400)});
    await expectLater(
      api.proximaSalida('r-1', Sentido.ida, desdeEmbarcaderoId: 'x'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'EMBARCADERO_FUERA_DE_RUTA')
          .having((e) => e.message, 'message', contains('no está en el sentido ida'))),
    );
  });

  test('Respuesta con otra forma: RESPUESTA_INVALIDA', () async {
    // /rutas devuelve un objeto en vez de una lista
    final (api, _) = _api({'/rutas': ('horarios.json', 200)});
    await expectLater(
      api.rutas(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RESPUESTA_INVALIDA')),
    );
  });
}
