// Volver a pedir los datos a la API. Lo usan "deslizar para actualizar" (Mapa y
// Embarcaderos), "Reintentar" y el regreso desde segundo plano. Lo guardado en el
// teléfono se sigue mostrando mientras llega lo nuevo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transport_mode.dart';
import 'data_providers.dart';
import 'piers_providers.dart';

/// Tiempo en segundo plano a partir del cual, al volver, se actualiza todo.
const refreshAfterBackground = Duration(minutes: 2);

/// Invalida embarcaderos, rutas, avisos y próximas salidas y espera a que la
/// lista de embarcaderos (base del Mapa y de la lista) vuelva a estar lista.
Future<void> refreshAllData(WidgetRef ref, TransportMode mode) async {
  ref
    ..invalidate(embarcaderosProvider)
    ..invalidate(rutasProvider)
    ..invalidate(rutaDetalleProvider)
    ..invalidate(avisosProvider)
    ..invalidate(proximaSalidaProvider)
    ..invalidate(horariosProvider);
  try {
    await ref.read(piersOverviewProvider(mode).future);
  } on Object {
    // El error se muestra en la pantalla
  }
}

/// Decide si al volver a la app hay que actualizar: solo si estuvo en segundo plano
/// al menos [refreshAfterBackground].
bool shouldRefreshOnResume(DateTime? pausedAt, DateTime now) =>
    pausedAt != null && now.difference(pausedAt) >= refreshAfterBackground;
