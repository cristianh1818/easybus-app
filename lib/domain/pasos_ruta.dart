// Horas estimadas de paso por cada embarcadero de un sentido, para una salida del
// origen: hora de salida + minutos desde el origen (los mismos que usa la API).
// En una parada intermedia es la hora en que la embarcación sale de ahí; en el
// destino, la de llegada. Siempre es horario PROGRAMADO, no tiempo real.

import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import 'proxima_salida_local.dart' show sumarMinutos;

const tipoDiaDe = {
  DayType.weekday: TipoDia.laboral,
  DayType.saturday: TipoDia.sabado,
  DayType.sundayHoliday: TipoDia.domingoFestivo,
};

/// Nombre del tipo de día para la pantalla.
String nombreTipoDia(TipoDia t) => switch (t) {
  TipoDia.laboral => 'Lunes a viernes',
  TipoDia.sabado => 'Sábado',
  TipoDia.domingoFestivo => 'Domingo o festivo',
};

class PasoPorParada {
  const PasoPorParada({required this.parada, required this.hora});

  final ParadaEnRuta parada;

  /// "HH:MM" (si pasa de medianoche, la hora del día siguiente).
  final String hora;
}

/// Paso por cada parada del sentido para la salida [salidaOrigen] ("HH:MM").
List<PasoPorParada> pasosDeSalida(RutaSentido sentido, String salidaOrigen) => [
  for (final p in sentido.paradas)
    PasoPorParada(parada: p, hora: sumarMinutos(salidaOrigen, p.minutosDesdeOrigen)),
];

/// Salidas desde el origen de un tipo de día, ordenadas y sin repetir.
List<String> salidasDelDia(List<Horario> horarios, TipoDia tipo) =>
    (horarios.where((h) => h.tipoDia == tipo).map((h) => h.horaSalida).toSet().toList()..sort());
