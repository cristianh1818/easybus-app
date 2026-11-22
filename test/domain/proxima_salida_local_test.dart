// Compara el cálculo local de la próxima salida con respuestas REALES del backend
// (GET /rutas/{id}/proxima-salida?momento=…), guardadas el 2026-11-22 junto con la
// ruta, los horarios y los festivos que el backend usó en ese momento.

import 'package:easybus_app/domain/proxima_salida_local.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/festivo.dart';
import 'package:easybus_app/models/horario.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/models/ruta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart' show readFixture;

/// "2026-11-10T07:03" en hora de Montería → instante (UTC−5).
DateTime bogota(String momento) => DateTime.parse('${momento}Z').add(const Duration(hours: 5));

void main() {
  final ruta = RutaDetalle.fromJson(asJsonMap(readFixture('comparacion_ruta_detalle.json')));
  final horarios = {
    Sentido.ida: HorariosSentido.fromJson(asJsonMap(readFixture('comparacion_horarios_ida.json'))).horarios,
    Sentido.vuelta: HorariosSentido.fromJson(asJsonMap(readFixture('comparacion_horarios_vuelta.json')))
        .horarios,
  };
  final festivos = asJsonList(
    readFixture('comparacion_festivos_2026.json'),
    Festivo.fromJson,
  ).map((f) => f.fecha).toSet();
  final casos = readFixture('comparacion_proxima_salida_casos.json')! as List;

  group('Igual que el backend', () {
    for (final caso in casos.cast<Map<String, Object?>>()) {
      test('${caso['nombre']} (${caso['momento']})', () {
        final sentido = Sentido.values.byName(caso['sentido']! as String);
        final esperado = ProximaSalida.fromJson(asJsonMap(caso['respuesta']));
        final local = calcularProximaSalidaLocal(
          ruta: ruta,
          sentido: sentido,
          desdeEmbarcaderoId: caso['desde'] as String?,
          horarios: horarios[sentido]!,
          festivos: festivos,
          instante: bogota(caso['momento']! as String),
        );

        expect(local.status, esperado.status, reason: 'status');
        expect(local.dayType, esperado.dayType, reason: 'tipo de día');
        expect(local.localDate, esperado.localDate);
        expect(local.localTime, esperado.localTime);
        expect(local.departureTime, esperado.departureTime, reason: 'hora de paso');
        expect(local.originDepartureTime, esperado.originDepartureTime, reason: 'salida del origen');
        expect(local.minutesRemaining, esperado.minutesRemaining, reason: 'minutos');
        expect(local.crossesMidnight, esperado.crossesMidnight);
        expect(local.message, esperado.message, reason: 'mismo texto');
        expect(local.destination, esperado.destination);
        expect(local.fromStop?.id, esperado.fromStop?.id);
        expect(local.fromStop?.order, esperado.fromStop?.order);
        expect(local.fromStop?.minutesFromOrigin, esperado.fromStop?.minutesFromOrigin);
        expect(local.notice, esperado.notice);
        expect(local.timeZone, esperado.timeZone);
        // El backend recorta los milisegundos al formatear esta fecha
        expect(
          local.scheduleUpdatedAt.difference(esperado.scheduleUpdatedAt).inMilliseconds.abs(),
          lessThan(1000),
        );
        final (l, e) = (local.nextDayFirstDeparture, esperado.nextDayFirstDeparture);
        expect(l?.date, e?.date, reason: 'fecha de mañana');
        expect(l?.dayType, e?.dayType, reason: 'tipo de día de mañana');
        expect(l?.departureTime, e?.departureTime);
        expect(l?.originDepartureTime, e?.originDepartureTime);
      });
    }
  });

  group('Piezas del cálculo', () {
    test('Hora de Montería sin importar la zona del teléfono (UTC−5, sin horario de verano)', () {
      final m = MomentoBogota(DateTime.utc(2026, 10, 28, 3, 30)); // 27 oct 22:30 en Montería
      expect((m.fecha, m.hora, m.minutos, m.diaSemana), ('2026-10-27', '22:30', 1350, 2));
      final julio = MomentoBogota(DateTime.utc(2026, 7, 1, 17));
      expect(julio.hora, '12:00', reason: 'Igual en julio: no hay cambio de hora');
    });

    test('Regla del tipo de día', () {
      for (final d in [1, 2, 3, 4, 5]) {
        expect(tipoDiaPara(d, false), TipoDia.laboral);
      }
      expect(tipoDiaPara(6, false), TipoDia.sabado);
      expect(tipoDiaPara(0, false), TipoDia.domingoFestivo);
      expect(tipoDiaPara(1, true), TipoDia.domingoFestivo, reason: 'lunes festivo');
      expect(tipoDiaPara(6, true), TipoDia.domingoFestivo, reason: 'sábado festivo');
    });

    test('Una salida de ayer que pasa hoy después de medianoche', () {
      // Salió ayer 23:50 y el embarcadero está a 20 min: pasa hoy 00:10
      final p = buscarProximoPaso(['05:30'], ['23:50'], 20, 5);
      expect(p!.horaPaso, '00:10');
      expect(p.salidaOrigen, '23:50');
      expect(p.minutosRestantes, 5);
    });

    test('Una salida de hoy que llega después de medianoche', () {
      final p = buscarProximoPaso(['23:50'], [], 20, 23 * 60 + 55);
      expect(p!.horaPaso, '00:10');
      expect(p.pasaDespuesDeMedianoche, isTrue);
      expect(p.minutosRestantes, 15);
    });

    test('Años de festivos necesarios en el cambio de año', () {
      expect(aniosNecesarios(bogota('2026-12-31T20:00')), {2026, 2027});
      expect(aniosNecesarios(bogota('2027-01-01T08:00')), {2026, 2027});
      expect(aniosNecesarios(bogota('2026-06-15T08:00')), {2026});
    });
  });
}
