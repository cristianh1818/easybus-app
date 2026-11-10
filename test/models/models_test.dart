// Los fixtures *.json son respuestas REALES de la API (GET) guardadas el 2026-11-10.
// Los *_sintetico.json se armaron a partir del código del backend porque en la base
// actual no hay avisos ni suspensiones.

import 'dart:convert';
import 'dart:io';

import 'package:easybus_app/models/aviso.dart';
import 'package:easybus_app/models/embarcadero.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/horario.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/models/ruta.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

Object? fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

/// Montería está cerca de lat 8.75, lng -75.88: detecta si se invirtió el orden GeoJSON.
Matcher get enMonteria => predicate<dynamic>(
  (p) => p.lat > 8.6 && p.lat < 8.9 && p.lng > -76.0 && p.lng < -75.8,
  'coordenada en Montería (lat, lng)',
);

void main() {
  group('Rutas', () {
    test('GET /rutas', () {
      final rutas = asJsonList(fixture('rutas.json'), Ruta.fromJson);
      expect(rutas, hasLength(1));
      final r = rutas.single;
      expect(r.codigo, 'BS-1');
      expect(r.mode, TransportMode.fluvial);
      expect(r.estado, EstadoRuta.activa);
      expect(r.esOficial, isFalse);
      expect(r.sentidos.map((s) => s.sentido), [Sentido.ida, Sentido.vuelta]);
    });

    test('GET /rutas/{id}: trazado, embarcaderos en orden y avisos', () {
      final d = RutaDetalle.fromJson(asJsonMap(fixture('ruta_detalle.json')));
      expect(d.ruta.codigo, 'BS-1');
      expect(d.avisos, isEmpty);
      expect(d.sentidos, hasLength(2));

      final ida = d.sentido(Sentido.ida)!;
      expect(ida.trazado, isNotNull);
      expect(ida.trazado!.length, greaterThan(1));
      expect(ida.trazado!.first, enMonteria);
      expect(ida.paradas.map((p) => p.orden), [1, 2, 3, 4, 5]);
      expect(ida.paradas.first.esOrigen, isTrue);
      expect(ida.paradas.first.minutosDesdeOrigen, 0);
      expect(ida.paradas.first.embarcadero.ubicacion, enMonteria);

      // Dato conocido del fixture: en vuelta, "Embarcadero Sur" queda lejos del trazado.
      final vuelta = d.sentido(Sentido.vuelta)!;
      expect(vuelta.paradas.first.lejosDelTrazado, isTrue);
      expect(vuelta.paradas.first.distanciaAlTrazadoM, 1442);
    });

    test('GET /rutas/{id}/horarios', () {
      final h = HorariosSentido.fromJson(asJsonMap(fixture('horarios.json')));
      expect(h.sentido, Sentido.ida);
      expect(h.horarios, isNotEmpty);
      expect(h.horarios.first.horaSalida, '05:30');
      expect(h.horarios.first.minutosDelDia, 330);
      expect(h.horarios.every((x) => x.tipoDia == TipoDia.laboral), isTrue);
    });
  });

  group('Embarcaderos', () {
    test('GET /embarcaderos', () {
      final lista = asJsonList(fixture('embarcaderos.json'), Embarcadero.fromJson);
      expect(lista, hasLength(8));
      for (final e in lista) {
        expect(e.mode, TransportMode.fluvial);
        expect(e.ubicacion, enMonteria);
      }
      // Accesibilidad sin dato: null, no false
      expect(lista.first.tieneRampa, isNull);
      expect(lista.first.margen, isNull);
    });

    test('GET /embarcaderos/{id}: rutas que lo atienden', () {
      final d = EmbarcaderoDetalle.fromJson(asJsonMap(fixture('embarcadero_detalle.json')));
      expect(d.embarcadero.nombre, 'Embarcadero Calle 37');
      final r = d.rutas.first;
      expect(r.ruta.codigo, 'BS-1');
      expect(r.ruta.mode, TransportMode.fluvial);
      expect(r.orden, 2);
      expect(r.totalEmbarcaderos, 5);
      expect(r.esOrigen, isFalse);
      expect(r.minutosDesdeOrigen, 12);
    });
  });

  group('Avisos (sintético)', () {
    test('Tipos, alcance y vigencia', () {
      final avisos = asJsonList(fixture('avisos_sintetico.json'), Aviso.fromJson);
      final [susp, retraso, info] = avisos;
      expect(susp.esSuspension, isTrue);
      expect(susp.motivo, MotivoAviso.nivelRio);
      expect(susp.alcance, AlcanceAviso.ruta);
      expect(susp.ruta!.codigo, 'BS-1');
      expect(susp.vigenteHasta, isNull);

      expect(retraso.tipo, TipoAviso.retraso);
      expect(retraso.embarcadero, isNotNull);
      expect(retraso.ruta, isNull);
      expect(retraso.vigenteHasta, DateTime.utc(2026, 11, 10, 18));

      expect(info.vigencia, VigenciaAviso.programado);
      expect(info.alcance, AlcanceAviso.general);
    });
  });

  group('Próxima salida (claves en inglés)', () {
    test('NEXT_DEPARTURE desde el origen', () {
      final p = ProximaSalida.fromJson(asJsonMap(fixture('proxima_salida_next.json')));
      expect(p.status, DepartureStatus.nextDeparture);
      expect(p.isScheduled, isTrue);
      expect(p.route.code, 'BS-1');
      expect(p.direction, Sentido.ida);
      expect(p.fromStop!.isOrigin, isTrue);
      expect(p.departureTime, matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(p.minutesRemaining, greaterThanOrEqualTo(0));
      expect(p.crossesMidnight, isFalse);
      expect(p.timeZone, 'America/Bogota');
      expect(p.notice, contains('horario programado'));
      expect(p.nextDayFirstDeparture, isNull);
    });

    test('NO_MORE_DEPARTURES_TODAY desde un embarcadero intermedio', () {
      final p = ProximaSalida.fromJson(asJsonMap(fixture('proxima_salida_no_more.json')));
      expect(p.status, DepartureStatus.noMoreDeparturesToday);
      expect(p.departureTime, isNull);
      expect(p.fromStop!.order, 2);
      expect(p.fromStop!.minutesFromOrigin, 12);
      final manana = p.nextDayFirstDeparture!;
      expect(manana.date, '2026-11-11');
      expect(manana.dayType, DayType.weekday);
      expect(manana.originDepartureTime, '05:30');
      expect(manana.departureTime, '05:42');
    });

    test('SUSPENDED con su aviso (sintético)', () {
      final p = ProximaSalida.fromJson(asJsonMap(fixture('proxima_salida_suspended_sintetico.json')));
      expect(p.status, DepartureStatus.suspended);
      expect(p.reason, MotivoAviso.nivelRio);
      expect(p.detail, isNotEmpty);
      expect(p.suspendedUntil, isNull);
      expect(p.departureTime, isNull);
      expect(p.alerts.single.type, TipoAviso.suspendido);
      expect(p.alerts.single.scope, AlcanceAviso.ruta);
    });
  });

  group('Robustez', () {
    test('Valores nuevos de la API no rompen la app', () {
      final json = asJsonMap(fixture('proxima_salida_next.json'))..['status'] = 'ALGO_NUEVO';
      expect(ProximaSalida.fromJson(json).status, DepartureStatus.unknown);

      final aviso = (fixture('avisos_sintetico.json') as List).first as Map<String, Object?>;
      expect(Aviso.fromJson({...aviso, 'tipo': 'otro_tipo'}).tipo, TipoAviso.informativo);

      final emb = (fixture('embarcaderos.json') as List).first as Map<String, Object?>;
      // Estado desconocido: se trata como cerrado (no anunciar zarpes por error)
      expect(Embarcadero.fromJson({...emb, 'estado': 'raro'}).estado, EstadoEmbarcadero.cerradoTemporal);
    });

    test('Un campo obligatorio faltante dice cuál es', () {
      final emb = Map<String, Object?>.from((fixture('embarcaderos.json') as List).first as Map)
        ..remove('nombre');
      expect(
        () => Embarcadero.fromJson(emb),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"nombre"'))),
      );
    });

    test('Hora con formato inválido', () {
      expect(
        () => Horario.fromJson({'id': 'x', 'tipoDia': 'laboral', 'horaSalida': '5:30'}),
        throwsFormatException,
      );
    });
  });
}
