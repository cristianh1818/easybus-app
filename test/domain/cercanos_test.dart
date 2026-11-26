import 'package:easybus_app/domain/cercanos.dart';
import 'package:easybus_app/models/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Embarcaderos reales de BS-1 (aproximados)
  const mariaVarilla = ('María Varilla', GeoPoint(8.762391, -75.884495), false);
  const avenida = ('Avenida primera', GeoPoint(8.756435, -75.889807), false);
  const sucre = ('Sucre', GeoPoint(8.771491, -75.880761), true); // cerrado
  const boca = ('Boca de la Ceiba', GeoPoint(8.827637, -75.856895), false);
  final todos = [boca, sucre, avenida, mariaVarilla];

  test('distanciaMetros: 0,01° de latitud son unos 1112 m', () {
    expect(distanciaMetros(const GeoPoint(8.75, -75.88), const GeoPoint(8.76, -75.88)), closeTo(1112, 2));
  });

  test('masCercanos ordena por distancia y deja los cerrados al final', () {
    const yo = GeoPoint(8.7700, -75.8820); // junto a Sucre, que está cerrado
    final r = masCercanos(yo, todos, ubicacion: (e) => e.$2, cerrado: (e) => e.$3);

    expect([for (final c in r) c.item.$1], ['María Varilla', 'Avenida primera', 'Boca de la Ceiba']);
    expect(r.first.metros, lessThan(r[1].metros));

    final sinPreferencia = masCercanos(yo, todos, ubicacion: (e) => e.$2, cantidad: 1);
    expect(sinPreferencia.single.item.$1, 'Sucre');
    expect(formatoDistancia(r.first.metros), endsWith(' m'));
    expect(formatoDistancia(1234), '1,2 km');
  });
}
