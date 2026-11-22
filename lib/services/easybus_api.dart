// Endpoints públicos de EASYBUS con tipos. Cada método devuelve el modelo ya
// convertido o lanza ApiException (mensaje en español).
//
// Cada endpoint es un ApiEndpoint (ruta, parámetros y parser, más la clave con que
// se guarda en la caché offline). Así el repository con caché puede pedir la
// respuesta cruda (JSON) para guardarla y convertirla después con el mismo parser.
//
// Privacidad (RNF-07): no hay endpoint para /embarcaderos/cercanos. El "cerca de mí"
// se calcula en el teléfono con embarcaderos(); la ubicación nunca sale del equipo.

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/festivo.dart';
import '../models/horario.dart';
import '../models/json.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import 'api_client.dart';

class ApiEndpoint<T> {
  const ApiEndpoint._(this.path, this.parse, {this.query = const {}, required this.cacheKey});

  final String path;
  final Map<String, Object?> query;
  final JsonParser<T> parse;

  /// Clave en la caché offline (única por ruta y parámetros).
  final String cacheKey;

  /// GET /rutas: rutas activas, sin trazados.
  static ApiEndpoint<List<Ruta>> rutas() =>
      ApiEndpoint._('/rutas', (j) => asJsonList(j, Ruta.fromJson), cacheKey: 'rutas');

  /// GET /rutas/{id}: sentidos con trazado y embarcaderos en orden, y avisos vigentes.
  static ApiEndpoint<RutaDetalle> ruta(String id) =>
      ApiEndpoint._('/rutas/${_seg(id)}', (j) => RutaDetalle.fromJson(asJsonMap(j)), cacheKey: 'ruta/$id');

  /// GET /rutas/{id}/horarios: salidas desde el origen. Sin [tipoDia], todas.
  static ApiEndpoint<HorariosSentido> horarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      ApiEndpoint._(
        '/rutas/${_seg(rutaId)}/horarios',
        (j) => HorariosSentido.fromJson(asJsonMap(j)),
        query: {'sentido': sentido.apiValue, 'tipoDia': tipoDia?.apiValue},
        cacheKey: 'horarios/$rutaId/${sentido.apiValue}/${tipoDia?.apiValue ?? 'todos'}',
      );

  /// GET /rutas/{id}/proxima-salida (no se guarda en la caché: depende de la hora).
  static ApiEndpoint<ProximaSalida> proximaSalida(
    String rutaId,
    Sentido sentido, {
    String? desdeEmbarcaderoId,
    String? momento,
  }) => ApiEndpoint._(
    '/rutas/${_seg(rutaId)}/proxima-salida',
    (j) => ProximaSalida.fromJson(asJsonMap(j)),
    query: {'sentido': sentido.apiValue, 'desde': desdeEmbarcaderoId, 'momento': momento},
    cacheKey: 'proxima-salida/$rutaId/${sentido.apiValue}/${desdeEmbarcaderoId ?? 'origen'}',
  );

  /// GET /embarcaderos: todos los visibles (activos y cerrados temporalmente).
  static ApiEndpoint<List<Embarcadero>> embarcaderos({TipoParada? tipo}) => ApiEndpoint._(
    '/embarcaderos',
    (j) => asJsonList(j, Embarcadero.fromJson),
    query: {'tipo': tipo?.apiValue},
    cacheKey: 'embarcaderos/${tipo?.apiValue ?? 'todos'}',
  );

  /// GET /embarcaderos/{id}: el embarcadero y las rutas que lo atienden.
  static ApiEndpoint<EmbarcaderoDetalle> embarcadero(String id) => ApiEndpoint._(
    '/embarcaderos/${_seg(id)}',
    (j) => EmbarcaderoDetalle.fromJson(asJsonMap(j)),
    cacheKey: 'embarcadero/$id',
  );

  /// GET /festivos?anio=: para calcular la próxima salida sin conexión.
  static ApiEndpoint<List<Festivo>> festivos(int anio) => ApiEndpoint._(
    '/festivos',
    (j) => asJsonList(j, Festivo.fromJson),
    query: {'anio': anio},
    cacheKey: 'festivos/$anio',
  );

  /// GET /avisos (no se guarda en la caché: un aviso viejo podría ser peligroso).
  static ApiEndpoint<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) => ApiEndpoint._(
    '/avisos',
    (j) => asJsonList(j, Aviso.fromJson),
    query: {'rutaId': rutaId, 'embarcaderoId': embarcaderoId},
    cacheKey: 'avisos/${rutaId ?? '-'}/${embarcaderoId ?? '-'}',
  );

  // Un id nunca debe poder cambiar la ruta de la URL ("../admin", "a/b").
  static String _seg(String id) => Uri.encodeComponent(id);
}

class EasybusApi {
  const EasybusApi(this._client);

  final ApiClient _client;

  Future<T> fetch<T>(ApiEndpoint<T> endpoint) =>
      _client.get(endpoint.path, query: endpoint.query, parse: endpoint.parse);

  /// El modelo y la respuesta cruda, para guardarla en la caché.
  Future<(T, Object?)> fetchWithJson<T>(ApiEndpoint<T> endpoint) =>
      _client.get(endpoint.path, query: endpoint.query, parse: (json) => (endpoint.parse(json), json));

  Future<List<Ruta>> rutas() => fetch(ApiEndpoint.rutas());

  Future<RutaDetalle> ruta(String id) => fetch(ApiEndpoint.ruta(id));

  Future<HorariosSentido> horarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      fetch(ApiEndpoint.horarios(rutaId, sentido, tipoDia: tipoDia));

  /// [momento] es solo para pruebas: hora local de Montería "AAAA-MM-DDTHH:mm".
  Future<ProximaSalida> proximaSalida(
    String rutaId,
    Sentido sentido, {
    String? desdeEmbarcaderoId,
    String? momento,
  }) => fetch(
    ApiEndpoint.proximaSalida(rutaId, sentido, desdeEmbarcaderoId: desdeEmbarcaderoId, momento: momento),
  );

  Future<List<Embarcadero>> embarcaderos({TipoParada? tipo}) => fetch(ApiEndpoint.embarcaderos(tipo: tipo));

  Future<EmbarcaderoDetalle> embarcadero(String id) => fetch(ApiEndpoint.embarcadero(id));

  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) =>
      fetch(ApiEndpoint.avisos(rutaId: rutaId, embarcaderoId: embarcaderoId));
}
