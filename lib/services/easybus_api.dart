// Endpoints públicos de EASYBUS con tipos. Cada método devuelve el modelo ya
// convertido o lanza ApiException (mensaje en español).
//
// Privacidad (RNF-07): no hay método para /embarcaderos/cercanos. El "cerca de mí"
// se calcula en el teléfono con embarcaderos(); la ubicación nunca sale del equipo.

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/horario.dart';
import '../models/json.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import 'api_client.dart';

class EasybusApi {
  const EasybusApi(this._client);

  final ApiClient _client;

  /// GET /rutas: rutas activas, sin trazados.
  Future<List<Ruta>> rutas() => _client.get('/rutas', parse: (j) => asJsonList(j, Ruta.fromJson));

  /// GET /rutas/{id}: sentidos con trazado y embarcaderos en orden, y avisos vigentes.
  Future<RutaDetalle> ruta(String id) =>
      _client.get('/rutas/${_seg(id)}', parse: (j) => RutaDetalle.fromJson(asJsonMap(j)));

  /// GET /rutas/{id}/horarios: salidas desde el origen. Sin [tipoDia], todas.
  Future<HorariosSentido> horarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) => _client.get(
    '/rutas/${_seg(rutaId)}/horarios',
    query: {'sentido': sentido.apiValue, 'tipoDia': tipoDia?.apiValue},
    parse: (j) => HorariosSentido.fromJson(asJsonMap(j)),
  );

  /// GET /rutas/{id}/proxima-salida: próximo paso por [desdeEmbarcaderoId]
  /// (o por el origen si se omite).
  ///
  /// [momento] es solo para pruebas: hora local de Montería "AAAA-MM-DDTHH:mm".
  /// Sin él, la API usa la hora actual.
  Future<ProximaSalida> proximaSalida(
    String rutaId,
    Sentido sentido, {
    String? desdeEmbarcaderoId,
    String? momento,
  }) => _client.get(
    '/rutas/${_seg(rutaId)}/proxima-salida',
    query: {'sentido': sentido.apiValue, 'desde': desdeEmbarcaderoId, 'momento': momento},
    parse: (j) => ProximaSalida.fromJson(asJsonMap(j)),
  );

  /// GET /embarcaderos: todos los visibles (activos y cerrados temporalmente).
  Future<List<Embarcadero>> embarcaderos({TipoParada? tipo}) => _client.get(
    '/embarcaderos',
    query: {'tipo': tipo?.apiValue},
    parse: (j) => asJsonList(j, Embarcadero.fromJson),
  );

  /// GET /embarcaderos/{id}: el embarcadero y las rutas que lo atienden.
  Future<EmbarcaderoDetalle> embarcadero(String id) =>
      _client.get('/embarcaderos/${_seg(id)}', parse: (j) => EmbarcaderoDetalle.fromJson(asJsonMap(j)));

  /// GET /avisos: avisos vigentes, opcionalmente de una ruta o de un embarcadero.
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) => _client.get(
    '/avisos',
    query: {'rutaId': rutaId, 'embarcaderoId': embarcaderoId},
    parse: (j) => asJsonList(j, Aviso.fromJson),
  );

  // Un id nunca debe poder cambiar la ruta de la URL ("../admin", "a/b").
  static String _seg(String id) => Uri.encodeComponent(id);
}
