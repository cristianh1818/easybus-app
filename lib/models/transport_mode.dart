// Modo de transporte. La fase 1 es fluvial (Businú); la fase 2 agrega buses
// reutilizando los mismos modelos, providers y pantallas.

import 'enums.dart';
import 'json.dart';

enum TransportMode implements ApiEnum {
  fluvial('fluvial'),
  bus('bus');

  const TransportMode(this.apiValue);

  /// Valor tal como lo envía la API (campo `modo`).
  @override
  final String apiValue;

  /// Convierte el valor de la API. Si llega un modo desconocido o nulo se asume
  /// fluvial, que es el único modo en servicio en la beta.
  static TransportMode fromApi(String? value) => enumFromApi(values, value, fluvial);

  /// Modo que corresponde a un tipo de parada.
  static TransportMode fromTipoParada(TipoParada tipo) => switch (tipo) {
    TipoParada.embarcadero => fluvial,
    TipoParada.paradaBus => bus,
  };
}
