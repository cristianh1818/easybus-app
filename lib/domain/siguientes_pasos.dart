// Pasos siguientes al próximo zarpe ("Luego: 07:42 · 08:12 · 08:42"), a partir de
// los horarios guardados. Usa el mismo tipo de día que respondió la API (o el cálculo
// local), así no necesita volver a decidir si hoy es festivo.

import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import 'proxima_salida_local.dart' show sumarMinutos;

const _tipoDia = {
  DayType.weekday: TipoDia.laboral,
  DayType.saturday: TipoDia.sabado,
  DayType.sundayHoliday: TipoDia.domingoFestivo,
};

/// Hasta [cuantos] horas de paso por el embarcadero después de [proxima], del
/// mismo día. Vacío si no hay una próxima salida normal (suspendido, sin más
/// salidas…) o si cruza la medianoche (el día siguiente puede ser otro tipo de día).
List<String> siguientesPasos(ProximaSalida proxima, List<Horario> horarios, {int cuantos = 3}) {
  final origen = proxima.originDepartureTime;
  if (proxima.status != DepartureStatus.nextDeparture || origen == null || proxima.crossesMidnight == true) {
    return const [];
  }
  final desfase = proxima.fromStop?.minutesFromOrigin ?? 0;
  final tipo = _tipoDia[proxima.dayType]!;
  final horas = horarios.where((h) => h.tipoDia == tipo).map((h) => h.horaSalida).toSet().toList()..sort();
  return [
    for (final h in horas)
      if (h.compareTo(origen) > 0) sumarMinutos(h, desfase),
  ].where((paso) => paso.compareTo(proxima.departureTime ?? '') > 0).take(cuantos).toList();
}
