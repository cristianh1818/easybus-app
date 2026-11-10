// Enums de la API (valores en minúscula, tal como los envía el backend).
// Los nombres en Dart van en español, igual que en la API.

import 'json.dart';

enum Sentido implements ApiEnum {
  ida('ida'),
  vuelta('vuelta');

  const Sentido(this.apiValue);
  @override
  final String apiValue;
}

/// Tipo de punto de parada. La API lo llama "embarcadero" aunque en la fase 2
/// también guardará paradas de bus.
enum TipoParada implements ApiEnum {
  embarcadero('embarcadero'),
  paradaBus('parada_bus');

  const TipoParada(this.apiValue);
  @override
  final String apiValue;
}

/// Orilla del río Sinú.
enum Margen implements ApiEnum {
  izquierda('izquierda'),
  derecha('derecha');

  const Margen(this.apiValue);
  @override
  final String apiValue;
}

enum EstadoEmbarcadero implements ApiEnum {
  activo('activo'),

  /// Sigue en las rutas, pero hoy no opera.
  cerradoTemporal('cerrado_temporal'),
  inactivo('inactivo');

  const EstadoEmbarcadero(this.apiValue);
  @override
  final String apiValue;
}

enum EstadoRuta implements ApiEnum {
  activa('activa'),
  inactiva('inactiva');

  const EstadoRuta(this.apiValue);
  @override
  final String apiValue;
}

enum TipoDia implements ApiEnum {
  laboral('laboral'),
  sabado('sabado'),
  domingoFestivo('domingo_festivo');

  const TipoDia(this.apiValue);
  @override
  final String apiValue;
}

enum TipoAviso implements ApiEnum {
  suspendido('suspendido'),
  retraso('retraso'),
  cambioHorario('cambio_horario'),
  informativo('informativo');

  const TipoAviso(this.apiValue);
  @override
  final String apiValue;
}

enum MotivoAviso implements ApiEnum {
  nivelRio('nivel_rio'),
  clima('clima'),
  mantenimiento('mantenimiento'),
  otro('otro');

  const MotivoAviso(this.apiValue);
  @override
  final String apiValue;
}

/// A qué afecta un aviso.
enum AlcanceAviso implements ApiEnum {
  /// Todo el servicio.
  general('general'),
  ruta('ruta'),

  /// Un embarcadero en todas las rutas que lo atienden.
  embarcadero('embarcadero'),

  /// Un embarcadero dentro de una ruta.
  rutaEmbarcadero('ruta_embarcadero');

  const AlcanceAviso(this.apiValue);
  @override
  final String apiValue;
}

/// Calculada por la API a partir de las fechas.
enum VigenciaAviso implements ApiEnum {
  programado('programado'),
  vigente('vigente'),
  vencido('vencido');

  const VigenciaAviso(this.apiValue);
  @override
  final String apiValue;
}
