import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:easybus_app/repositories/easybus_repository.dart';
import 'package:easybus_app/repositories/fetched.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/services/cache/app_database.dart';
import 'package:easybus_app/services/cache/response_cache.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// API falsa: responde con fixtures o simula "sin conexión".
class _Adapter implements HttpClientAdapter {
  bool offline = false;
  int calls = 0;

  static const _files = {
    '/api/v1/embarcaderos': 'embarcaderos.json',
    '/api/v1/rutas': 'rutas.json',
    '/api/v1/avisos': 'avisos_sintetico.json',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls++;
    if (offline) throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    final file = _files[o.uri.path] ?? (throw StateError('Sin fixture para ${o.uri.path}'));
    return ResponseBody.fromString(
      File('test/fixtures/$file').readAsStringSync(),
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
  late AppDatabase db;
  late ResponseCache cache;
  late _Adapter adapter;
  late CachedEasybusRepository repo;
  var now = DateTime(2026, 11, 10, 8);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cache = ResponseCache(db);
    adapter = _Adapter();
    final api = EasybusApi(ApiClient(baseUrl: 'http://x/api/v1', dio: Dio()..httpClientAdapter = adapter));
    now = DateTime(2026, 11, 10, 8);
    repo = CachedEasybusRepository(api, cache, now: () => now);
  });
  tearDown(() => db.close());

  test('Primera vez (sin caché): emite la respuesta de la red y la guarda', () async {
    final events = await repo.watchEmbarcaderos().toList();
    expect(events, hasLength(1));
    expect(events.single.origin, DataOrigin.network);
    expect(events.single.data, hasLength(8));
    expect(await cache.read('embarcaderos/todos'), isNotNull);
  });

  test('Con caché: primero lo guardado (al instante) y luego lo actualizado', () async {
    await repo.watchEmbarcaderos().toList(); // guarda a las 08:00
    now = DateTime(2026, 11, 10, 9);

    final events = await repo.watchEmbarcaderos().toList();
    expect(events.map((e) => e.origin), [DataOrigin.cache, DataOrigin.network]);
    expect(events.first.updatedAt, DateTime(2026, 11, 10, 8));
    expect(events.first.data, hasLength(8), reason: 'El JSON guardado se convierte con el mismo fromJson');
    expect(events.last.updatedAt, DateTime(2026, 11, 10, 9));
  });

  test('Sin conexión con caché: muestra lo guardado marcado como "sin conexión"', () async {
    await repo.watchEmbarcaderos().toList();
    adapter.offline = true;

    final events = await repo.watchEmbarcaderos().toList();
    expect(events, hasLength(2));
    expect(events.last.origin, DataOrigin.cache);
    expect(events.last.isStale, isTrue);
    expect(events.last.refreshError!.isOffline, isTrue);
    expect(events.last.updatedAt, DateTime(2026, 11, 10, 8));
  });

  test('Sin conexión y sin caché: el error llega a la pantalla', () async {
    adapter.offline = true;
    await expectLater(
      repo.watchEmbarcaderos().toList(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SIN_CONEXION')),
    );
  });

  test('Una fila de otro formato o dañada se ignora y se vuelve a descargar', () async {
    await db
        .into(db.cacheEntries)
        .insert(
          CacheEntriesCompanion.insert(
            key: 'rutas',
            json: '{"esto": "no es una lista"}',
            updatedAt: 0,
            formatVersion: cacheFormatVersion,
          ),
        );
    final events = await repo.watchRutas().toList();
    expect(events.map((e) => e.origin), [DataOrigin.network], reason: 'La fila dañada no se muestra');
    expect(events.single.data.single.codigo, 'BS-1');

    await (db.update(db.cacheEntries)..where((t) => t.key.equals('rutas'))).write(
      const CacheEntriesCompanion(formatVersion: Value(cacheFormatVersion - 1)),
    );
    expect(await cache.read('rutas'), isNull, reason: 'Formato anterior: se ignora');
  });

  test('Los avisos nunca se guardan: sin conexión no se muestran avisos viejos', () async {
    expect(await repo.avisos(), hasLength(3));
    adapter.offline = true;
    await expectLater(repo.avisos(), throwsA(isA<ApiException>()));
    final rows = await db.select(db.cacheEntries).get();
    expect(rows.where((r) => r.key.startsWith('avisos')), isEmpty);
  });

  test('Borrar la caché', () async {
    await repo.watchEmbarcaderos().toList();
    await cache.clear();
    expect(await db.select(db.cacheEntries).get(), isEmpty);
  });
}
