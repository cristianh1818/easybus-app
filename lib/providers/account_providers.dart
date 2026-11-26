// Estado de la cuenta: la sesión (o null = sin sesión, que es lo normal) y los
// favoritos del pasajero con sesión.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cuenta.dart';
import '../services/account_service.dart';
import '../services/api_exception.dart';
import 'api_providers.dart';
import 'clock_provider.dart';

final accountApiProvider = Provider<AccountApi>((ref) => AccountApi(ref.watch(apiClientProvider)));

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Sesión actual. Al abrir la app se lee la guardada; si ya venció, se descarta.
final sessionProvider = AsyncNotifierProvider<SessionNotifier, Sesion?>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() async {
    final store = ref.read(sessionStoreProvider);
    final saved = await store.read();
    if (saved == null) return null;
    if (saved.vencida(ref.read(nowProvider)())) {
      await store.clear();
      return null;
    }
    return saved;
  }

  /// Lanza ApiException con el mensaje en español ("Correo o contraseña incorrectos").
  Future<void> login({required String correo, required String password}) async {
    final sesion = await ref
        .read(accountApiProvider)
        .login(correo: correo, password: password, ahora: ref.read(nowProvider)());
    await _save(sesion);
  }

  Future<void> register({required String nombre, required String correo, required String password}) async {
    final sesion = await ref
        .read(accountApiProvider)
        .register(nombre: nombre, correo: correo, password: password, ahora: ref.read(nowProvider)());
    await _save(sesion);
  }

  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> _save(Sesion sesion) async {
    await ref.read(sessionStoreProvider).write(sesion);
    state = AsyncData(sesion);
  }
}

/// Favoritos del pasajero con sesión (null = sin sesión). Siempre desde la API.
final favoritesProvider = AsyncNotifierProvider<FavoritesNotifier, Favoritos?>(FavoritesNotifier.new);

class FavoritesNotifier extends AsyncNotifier<Favoritos?> {
  @override
  Future<Favoritos?> build() async {
    final sesion = await ref.watch(sessionProvider.future);
    if (sesion == null) return null;
    return _guard(sesion, () => ref.read(accountApiProvider).favoritos(sesion.token));
  }

  /// Guarda o quita. Lanza ApiException si falla (la pantalla muestra el mensaje).
  Future<void> toggle({required String tipo, required String id, required bool guardar}) async {
    final sesion = ref.read(sessionProvider).value;
    if (sesion == null) return;
    final api = ref.read(accountApiProvider);
    if (guardar) {
      state = AsyncData(await _guard(sesion, () => api.agregarFavorito(sesion.token, tipo: tipo, id: id)));
    } else {
      await _guard(sesion, () => api.quitarFavorito(sesion.token, tipo: tipo, id: id));
      final actual = state.value ?? Favoritos.vacio;
      state = AsyncData(
        Favoritos(
          rutas: [
            for (final r in actual.rutas)
              if (tipo != 'ruta' || r.id != id) r,
          ],
          embarcaderos: [
            for (final e in actual.embarcaderos)
              if (tipo != 'embarcadero' || e.id != id) e,
          ],
        ),
      );
    }
  }

  /// Un 401 significa que la sesión venció en el servidor: se cierra.
  Future<T> _guard<T>(Sesion sesion, Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await ref.read(sessionProvider.notifier).logout();
        throw const ApiException(
          kind: ApiErrorKind.client,
          statusCode: 401,
          code: 'SESION_VENCIDA',
          message: 'Tu sesión venció. Inicia sesión de nuevo para ver tus favoritos.',
        );
      }
      rethrow;
    }
  }
}
