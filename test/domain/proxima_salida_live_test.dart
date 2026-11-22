// Compara el cálculo local con la API real en muchos momentos (solo GET).
// No corre por defecto:
//   flutter test test/domain/proxima_salida_live_test.dart --dart-define=API_EN_VIVO=true

import 'dart:io';

import 'package:easybus_app/config/app_config.dart';
import 'package:easybus_app/domain/proxima_salida_local.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_test/flutter_test.dart';

const _enVivo = bool.fromEnvironment('API_EN_VIVO');

String _momento(DateTime bogotaLocal) {
  String d(int v) => v.toString().padLeft(2, '0');
  return '${bogotaLocal.year}-${d(bogotaLocal.month)}-${d(bogotaLocal.day)}T${d(bogotaLocal.hour)}:${d(bogotaLocal.minute)}';
}

void main() {
  setUpAll(() => HttpOverrides.global = null);

  test(
    '60 momentos: el teléfono calcula lo mismo que la API',
    () async {
      final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
      final api = EasybusApi(client);
      addTearDown(client.close);

      final rutaId = (await api.rutas()).first.id;
      final ruta = await api.ruta(rutaId);
      final horarios = {for (final s in Sentido.values) s: (await api.horarios(rutaId, s)).horarios};
      final festivos = {
        for (final anio in [2026, 2027]) ...(await api.fetch(ApiEndpoint.festivos(anio))).map((f) => f.fecha),
      };

      var comparados = 0;
      final diferencias = <String>[];
      // Del sábado 14 al martes 17 de noviembre (con el lunes festivo) y el 7-8 de
      // diciembre, cada 97 minutos para caer en minutos variados
      final inicios = [DateTime.utc(2026, 11, 14), DateTime.utc(2026, 12, 7)];
      for (final inicio in inicios) {
        for (
          var t = inicio;
          comparados < 60 && t.isBefore(inicio.add(const Duration(days: 3)));
          t = t.add(const Duration(minutes: 97))
        ) {
          final sentido = comparados.isEven ? Sentido.ida : Sentido.vuelta;
          final paradas = ruta.sentido(sentido)!.paradas;
          final desde = paradas[comparados % paradas.length].embarcadero.id;
          final momento = _momento(t);

          final remoto = await api.proximaSalida(
            rutaId,
            sentido,
            desdeEmbarcaderoId: desde,
            momento: momento,
          );
          final local = calcularProximaSalidaLocal(
            ruta: ruta,
            sentido: sentido,
            desdeEmbarcaderoId: desde,
            horarios: horarios[sentido]!,
            festivos: festivos,
            instante: t.add(const Duration(hours: 5)),
          );
          final a = (
            local.status,
            local.dayType,
            local.departureTime,
            local.minutesRemaining,
            local.message,
            local.nextDayFirstDeparture?.departureTime,
          );
          final b = (
            remoto.status,
            remoto.dayType,
            remoto.departureTime,
            remoto.minutesRemaining,
            remoto.message,
            remoto.nextDayFirstDeparture?.departureTime,
          );
          if (a != b) diferencias.add('$momento ${sentido.apiValue}: local $a ≠ API $b');
          comparados++;
          // Por debajo del límite de 100 peticiones por minuto de la API
          await Future<void>.delayed(const Duration(milliseconds: 700));
        }
      }
      expect(comparados, 60);
      expect(diferencias, isEmpty, reason: diferencias.join('\n'));
    },
    skip: !_enVivo,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
