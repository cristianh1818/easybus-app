import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easybus_app/providers/api_providers.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/providers/retry_policy.dart';
import 'package:easybus_app/repositories/easybus_repository.dart';
import 'package:easybus_app/repositories/fetched.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixtureAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls++;
    return ResponseBody.fromString(
      File('test/fixtures/embarcaderos.json').readAsStringSync(),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('El repository de API emite una vez, desde la red y con la hora de descarga', () async {
    final adapter = _FixtureAdapter();
    final api = EasybusApi(ApiClient(baseUrl: 'http://x/api/v1', dio: Dio()..httpClientAdapter = adapter));
    final repo = ApiEasybusRepository(api, now: () => DateTime(2026, 11, 10, 8));

    final emitted = await repo.watchEmbarcaderos().toList();
    expect(emitted, hasLength(1));
    expect(emitted.single.origin, DataOrigin.network);
    expect(emitted.single.updatedAt, DateTime(2026, 11, 10, 8));
    expect(emitted.single.data, hasLength(8));
    expect(emitted.single.isStale, isFalse);
  });

  test('embarcaderosProvider se conserva en la sesión (no descarga dos veces)', () async {
    final adapter = _FixtureAdapter();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'http://x/api/v1', dio: Dio()..httpClientAdapter = adapter),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(embarcaderosProvider, (_, _) {});
    final first = await container.read(embarcaderosProvider.future);
    sub.close();
    await container.read(embarcaderosProvider.future);
    expect(first.data, hasLength(8));
    expect(adapter.calls, 1);
  });

  group('Política de reintentos', () {
    const sinConexion = ApiException(kind: ApiErrorKind.noConnection, code: 'SIN_CONEXION', message: '');
    const invalido = ApiException(
      kind: ApiErrorKind.client,
      code: 'DATOS_INVALIDOS',
      message: '',
      statusCode: 400,
    );

    test('Reintenta sin conexión a 1, 2 y 4 s, y luego se rinde', () {
      expect(apiRetryPolicy(0, sinConexion), const Duration(seconds: 1));
      expect(apiRetryPolicy(1, sinConexion), const Duration(seconds: 2));
      expect(apiRetryPolicy(2, sinConexion), const Duration(seconds: 4));
      expect(apiRetryPolicy(3, sinConexion), isNull);
    });

    test('No reintenta errores que no se arreglan solos', () {
      expect(apiRetryPolicy(0, invalido), isNull);
      expect(apiRetryPolicy(0, StateError('bug')), isNull);
    });
  });
}
