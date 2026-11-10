import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador falso: responde sin red y guarda la última petición.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body, Future<void>? cancel) {
    last = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

(ApiClient, _FakeAdapter) _client(Future<ResponseBody> Function(RequestOptions) handler) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiClient(baseUrl: 'http://localhost:3000/api/v1', dio: dio), adapter);
}

Future<ApiException> _error(Future<Object?> call) async {
  try {
    await call;
  } on ApiException catch (e) {
    return e;
  }
  fail('Se esperaba ApiException');
}

void main() {
  test('Arma la URL con la base y no envía parámetros nulos', () async {
    final (api, adapter) = _client((_) async => _json([], 200));
    await api.get('/avisos', query: {'rutaId': 'r1', 'embarcaderoId': null}, parse: (j) => j);
    expect(adapter.last!.uri.toString(), 'http://localhost:3000/api/v1/avisos?rutaId=r1');
  });

  test('Devuelve lo que entrega el parser', () async {
    final (api, _) = _client((_) async => _json([
          {'id': 'a'},
          {'id': 'b'},
        ], 200));
    final ids = await api.get('/rutas', parse: (j) => [for (final r in j as List) (r as Map)['id'] as String]);
    expect(ids, ['a', 'b']);
  });

  test('Error de la API: conserva code, message y errores en español', () async {
    final (api, _) = _client((_) async => _json({
          'statusCode': 400,
          'code': 'DATOS_INVALIDOS',
          'message': 'lat no es una latitud válida',
          'errores': ['lat no es una latitud válida'],
        }, 400));
    final e = await _error(api.get('/rutas/x', parse: (j) => j));
    expect(e.kind, ApiErrorKind.client);
    expect(e.statusCode, 400);
    expect(e.code, 'DATOS_INVALIDOS');
    expect(e.message, 'lat no es una latitud válida');
    expect(e.errors, ['lat no es una latitud válida']);
    expect(e.isRetryable, isFalse);
  });

  test('Error 502 sin JSON (página de Nginx): mensaje genérico y reintentable', () async {
    final (api, _) = _client((_) async => ResponseBody.fromString('<html>Bad Gateway</html>', 502,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        }));
    final e = await _error(api.get('/rutas', parse: (j) => j));
    expect(e.kind, ApiErrorKind.server);
    expect(e.code, 'SERVICIO_NO_DISPONIBLE');
    expect(e.isRetryable, isTrue);
  });

  test('Sin conexión: SIN_CONEXION, reintentable y se puede usar la caché', () async {
    final (api, _) = _client((o) async =>
        throw DioException.connectionError(requestOptions: o, reason: 'Connection refused'));
    final e = await _error(api.get('/rutas', parse: (j) => j));
    expect(e.code, 'SIN_CONEXION');
    expect(e.isRetryable, isTrue);
    expect(e.isOffline, isTrue);
  });

  test('Tiempo agotado', () async {
    final (api, _) = _client((o) async =>
        throw DioException.receiveTimeout(timeout: const Duration(seconds: 15), requestOptions: o));
    final e = await _error(api.get('/rutas', parse: (j) => j));
    expect(e.kind, ApiErrorKind.timeout);
    expect(e.isOffline, isTrue);
  });

  test('Respuesta con forma inesperada: RESPUESTA_INVALIDA', () async {
    final (api, _) = _client((_) async => _json({'no': 'es una lista'}, 200));
    final e = await _error(api.get('/rutas', parse: (j) => (j as List).length));
    expect(e.code, 'RESPUESTA_INVALIDA');
  });
}
