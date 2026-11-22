// Providers de datos que usan las pantallas. Leen del repository, nunca de la API
// directamente: el repository decide si los datos vienen de la caché o de la red.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import '../repositories/easybus_repository.dart';
import '../repositories/fetched.dart';
import 'api_providers.dart';
import 'cache_providers.dart';
import 'clock_provider.dart';

/// Caché offline (SQLite) + API: primero lo guardado, luego lo actualizado.
final easybusRepositoryProvider = Provider<EasybusRepository>(
  (ref) => CachedEasybusRepository(
    ref.watch(easybusApiProvider),
    ref.watch(responseCacheProvider),
    now: ref.watch(nowProvider),
  ),
);

// Listas: se conservan durante la sesión (cambiar de pestaña no vuelve a descargarlas).
// Para actualizar: ref.invalidate(embarcaderosProvider).

final embarcaderosProvider = StreamProvider<Fetched<List<Embarcadero>>>(
  (ref) => ref.watch(easybusRepositoryProvider).watchEmbarcaderos(),
);

final rutasProvider = StreamProvider<Fetched<List<Ruta>>>(
  (ref) => ref.watch(easybusRepositoryProvider).watchRutas(),
);

// Detalles: se liberan al salir de la pantalla.

final embarcaderoDetalleProvider = StreamProvider.autoDispose.family<Fetched<EmbarcaderoDetalle>, String>(
  (ref, id) => ref.watch(easybusRepositoryProvider).watchEmbarcadero(id),
);

final rutaDetalleProvider = StreamProvider.autoDispose.family<Fetched<RutaDetalle>, String>(
  (ref, id) => ref.watch(easybusRepositoryProvider).watchRuta(id),
);

typedef HorariosArgs = ({String rutaId, Sentido sentido, TipoDia? tipoDia});

final horariosProvider = StreamProvider.autoDispose.family<Fetched<HorariosSentido>, HorariosArgs>(
  (ref, a) => ref.watch(easybusRepositoryProvider).watchHorarios(a.rutaId, a.sentido, tipoDia: a.tipoDia),
);

// Siempre desde la API.

typedef AvisosArgs = ({String? rutaId, String? embarcaderoId});

/// Avisos vigentes. `(rutaId: null, embarcaderoId: null)` = todos.
final avisosProvider = FutureProvider.autoDispose.family<List<Aviso>, AvisosArgs>(
  (ref, a) => ref.watch(easybusRepositoryProvider).avisos(rutaId: a.rutaId, embarcaderoId: a.embarcaderoId),
);

typedef ProximaSalidaArgs = ({String rutaId, Sentido sentido, String? desdeEmbarcaderoId});

/// Próxima salida con la hora en que se consultó: la pantalla descuenta los minutos
/// que pasan (con clockProvider) y vuelve a consultar cuando la salida ya pasó.
final proximaSalidaProvider = FutureProvider.autoDispose.family<Fetched<ProximaSalida>, ProximaSalidaArgs>((
  ref,
  a,
) async {
  final now = ref.watch(nowProvider);
  final p = await ref
      .watch(easybusRepositoryProvider)
      .proximaSalida(a.rutaId, a.sentido, desdeEmbarcaderoId: a.desdeEmbarcaderoId);
  return Fetched(p, updatedAt: now(), origin: DataOrigin.network);
});
