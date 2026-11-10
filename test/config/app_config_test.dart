import 'package:easybus_app/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String parse(String raw, {bool release = false}) => AppConfig.parseApiBaseUrl(raw, release: release);

  test('Por defecto apunta a localhost (teléfono por USB con adb reverse)', () {
    expect(AppConfig.apiBaseUrl, 'http://localhost:3000/api/v1');
  });

  test('Quita la barra final', () {
    expect(parse('http://10.0.2.2:3000/api/v1/'), 'http://10.0.2.2:3000/api/v1');
  });

  test('Rechaza URLs inválidas', () {
    expect(() => parse('localhost:3000'), throwsStateError);
    expect(() => parse('ftp://x.co/api'), throwsStateError);
    expect(() => parse(''), throwsStateError);
  });

  test('En release exige HTTPS', () {
    expect(() => parse('http://api.easybus.co/api/v1', release: true), throwsStateError);
    expect(parse('https://api.easybus.co/api/v1', release: true), 'https://api.easybus.co/api/v1');
  });
}
