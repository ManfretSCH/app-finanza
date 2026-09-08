// La direccion del backend define contra que servidor habla el APK repartido.
// Si esta logica se rompe, la app compila pero no conecta con nada.

import 'package:app_finanzas/core/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('en el emulador de Android se usa 10.0.2.2, no localhost', () {
    // "localhost" dentro del emulador apunta al propio emulador, no a la Mac.
    expect(
      resolverUrlBase(definidaAlCompilar: '', esAndroid: true),
      'http://10.0.2.2:8000/api/v1',
    );
  });

  test('en el simulador de iOS y en escritorio se usa localhost', () {
    expect(
      resolverUrlBase(definidaAlCompilar: '', esAndroid: false),
      'http://localhost:8000/api/v1',
    );
  });

  test('la dirección definida al compilar gana sobre la de desarrollo', () {
    // Es el caso del APK que se reparte al equipo: apunta a la IP de la
    // maquina donde corre el backend.
    const enLaRedLocal = 'http://192.168.0.5:8000/api/v1';
    expect(
      resolverUrlBase(definidaAlCompilar: enLaRedLocal, esAndroid: true),
      enLaRedLocal,
    );
    expect(
      resolverUrlBase(definidaAlCompilar: enLaRedLocal, esAndroid: false),
      enLaRedLocal,
    );
  });
}
