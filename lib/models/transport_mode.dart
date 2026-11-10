// Modo de transporte. La fase 1 es fluvial (Businú); la fase 2 agrega buses
// reutilizando los mismos modelos, providers y pantallas.

enum TransportMode {
  fluvial('fluvial'),
  bus('bus');

  const TransportMode(this.apiValue);

  /// Valor tal como lo envía la API (campo `modo`).
  final String apiValue;

  /// Convierte el valor de la API. Si llega un modo desconocido o nulo se asume
  /// fluvial, que es el único modo en servicio en la beta.
  static TransportMode fromApi(String? value) =>
      values.firstWhere((m) => m.apiValue == value, orElse: () => fluvial);
}
