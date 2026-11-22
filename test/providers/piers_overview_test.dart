import 'dart:async';

import 'package:easybus_app/models/embarcadero.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/providers/piers_providers.dart';
import 'package:easybus_app/repositories/fetched.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';

/// Emite primero "lo guardado" (2 embarcaderos) y luego "lo de la red" (los 8).
class _CacheThenNetworkRepo extends FakeRepository {
  final network = Completer<void>();

  @override
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos() async* {
    final all = asJsonList(readFixture('embarcaderos.json'), Embarcadero.fromJson);
    yield Fetched(all.take(2).toList(), updatedAt: DateTime(2026, 11, 9), origin: DataOrigin.cache);
    await network.future;
    yield Fetched(all, updatedAt: DateTime(2026, 11, 10), origin: DataOrigin.network);
  }
}

void main() {
  test('La lista muestra primero lo guardado y se actualiza al llegar lo de la red', () async {
    final repo = _CacheThenNetworkRepo();
    final container = ProviderContainer(
      overrides: [easybusRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final seen = <int>[];
    container.listen(piersOverviewProvider(TransportMode.fluvial), (_, next) {
      if (next.hasValue && !next.isLoading) seen.add(next.requireValue.items.length);
    }, fireImmediately: true);

    final first = await container.read(piersOverviewProvider(TransportMode.fluvial).future);
    expect(first.items, hasLength(2));
    expect(first.updatedAt, DateTime(2026, 11, 9));

    repo.network.complete();
    await pumpEventQueue();
    final second = await container.read(piersOverviewProvider(TransportMode.fluvial).future);
    expect(second.items, hasLength(8));
    expect(seen, [2, 8]);
  });
}
