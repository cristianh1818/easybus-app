// Proveedor del mapa base: el ÚNICO lugar donde se elige de dónde salen las teselas.
// Las pantallas no conocen el paquete de mapas: usan EbRiverMap (widgets/map), que
// recibe GeoPoint. Para cambiar a Google Maps más adelante se reemplaza EbRiverMap y
// este archivo; las pantallas no cambian.

import 'package:flutter/foundation.dart';

import '../models/geo.dart';

/// Una fuente de teselas raster con su atribución obligatoria.
@immutable
class EbTileStyle {
  const EbTileStyle({
    required this.urlTemplate,
    required this.attributions,
    this.subdomains = const [],
    this.maxNativeZoom = 19,
    this.supportsRetina = false,
  });

  /// Plantilla de URL ({s} subdominio, {z}/{x}/{y}, {r} = "@2x" en pantallas densas).
  final String urlTemplate;
  final List<String> subdomains;
  final int maxNativeZoom;
  final bool supportsRetina;

  /// Textos y enlaces que deben verse sobre el mapa (condición de uso).
  final List<({String text, String url})> attributions;
}

abstract final class EbMapConfig {
  /// Identifica la app ante el servidor de teselas (política de uso de OSM: User-Agent
  /// propio, no el genérico de la librería).
  static const userAgentPackageName = 'co.easybus.easybus_app';

  /// Río Sinú a su paso por el centro de Montería (igual que el panel).
  static const center = GeoPoint(8.7545, -75.8835);
  static const initialZoom = 14.0;
  static const minZoom = 11.0;
  static const maxZoom = 18.0;

  /// Estilo en uso: teselas estándar de OpenStreetMap, las mismas del panel, sin
  /// clave. (CARTO se descartó: sus teselas exigen API key.)
  static const tiles = osmStandard;

  /// Política de uso de tile.openstreetmap.org: User-Agent propio
  /// ([userAgentPackageName]), atribución "© OpenStreetMap" visible y sin descargas
  /// masivas ni precarga de zonas; flutter_map guarda las teselas en caché
  /// respetando los encabezados del servidor. Si el tráfico crece, pasar a un
  /// proveedor con plan o a un servidor propio (solo cambia este archivo).
  static const osmStandard = EbTileStyle(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attributions: [(text: '© OpenStreetMap', url: 'https://www.openstreetmap.org/copyright')],
  );
}
