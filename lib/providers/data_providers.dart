// Providers de datos que usan las pantallas. Leen del repository, nunca de la API
// directamente, para que la caché offline se pueda agregar sin tocar las pantallas.

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

final easybusRepositoryProvider = Provider<EasybusRepository>(
  (ref) => ApiEasybusRepository(ref.watch(easybusApiProvider)),
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

final proximaSalidaProvider = FutureProvider.autoDispose.family<ProximaSalida, ProximaSalidaArgs>(
  (ref, a) => ref
      .watch(easybusRepositoryProvider)
      .proximaSalida(a.rutaId, a.sentido, desdeEmbarcaderoId: a.desdeEmbarcaderoId),
);
