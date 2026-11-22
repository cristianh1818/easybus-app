import 'package:easybus_app/domain/siguientes_pasos.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/horario.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart' show readFixture;

ProximaSalida _proxima(Map<String, Object?> cambios) =>
    ProximaSalida.fromJson({...asJsonMap(readFixture('proxima_salida_next.json')), ...cambios});

List<Horario> _horarios(Map<TipoDia, List<String>> porTipo) => [
  for (final MapEntry(key: tipo, value: horas) in porTipo.entries)
    for (final h in horas) Horario(id: '$tipo-$h', tipoDia: tipo, horaSalida: h),
];

void main() {
  final horarios = _horarios({
    TipoDia.laboral: ['05:30', '06:00', '06:30', '07:00'],
    TipoDia.domingoFestivo: ['07:00', '09:00', '11:00', '13:00'],
  });

  test('Desde un embarcadero intermedio suma los minutos desde el origen', () {
    final p = _proxima({
      'departureTime': '06:12',
      'originDepartureTime': '06:00',
      'fromStop': {
        ...asJsonMap(readFixture('proxima_salida_next.json'))['fromStop']! as Map,
        'minutesFromOrigin': 12,
      },
    });
    expect(siguientesPasos(p, horarios), ['06:42', '07:12']);
  });

  test('Usa el tipo de día que respondió la API (festivo → horario de festivo)', () {
    final p = _proxima({
      'dayType': 'SUNDAY_HOLIDAY',
      'departureTime': '07:00',
      'originDepartureTime': '07:00',
    });
    expect(siguientesPasos(p, horarios, cuantos: 2), ['09:00', '11:00']);
  });

  test('Sin próxima salida normal no muestra siguientes', () {
    expect(siguientesPasos(_proxima({'status': 'SUSPENDED'}), horarios), isEmpty);
    expect(siguientesPasos(_proxima({'status': 'NO_MORE_DEPARTURES_TODAY'}), horarios), isEmpty);
    expect(siguientesPasos(_proxima({'crossesMidnight': true}), horarios), isEmpty);
  });
}
