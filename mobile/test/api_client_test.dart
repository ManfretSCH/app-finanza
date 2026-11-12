// La direccion del backend define contra que servidor habla el APK repartido.
// Si esta logica se rompe, la app compila pero no conecta con nada.

import 'package:app_finanzas/core/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // El backend en la capa gratuita de Render se duerme tras un rato sin uso, y el
  // primer pedido despues tiene que esperar a que arranque. Con 10 s de espera
  // ese pedido fallaba siempre y el usuario veia "No se pudo conectar".
  test('se espera al menos dos minutos a que el servidor responda', () {
    final dio = ApiClient(const FlutterSecureStorage()).dio;
    expect(dio.options.receiveTimeout, greaterThanOrEqualTo(const Duration(minutes: 2)));
  });

  group('mensajeDeError', () {
    DioException errorDeTipo(DioExceptionType tipo) =>
        DioException(requestOptions: RequestOptions(), type: tipo);

    test('si la respuesta no llega a tiempo, invita a reintentar', () {
      final mensaje = mensajeDeError(errorDeTipo(DioExceptionType.receiveTimeout));
      expect(mensaje, contains('tardó demasiado en responder'));
      expect(mensaje, contains('intenta de nuevo'));
    });

    test('si no se pudo conectar, lo dice así', () {
      for (final tipo in [DioExceptionType.connectionError, DioExceptionType.connectionTimeout]) {
        expect(mensajeDeError(errorDeTipo(tipo)), startsWith('No se pudo conectar'));
      }
    });

    test('el detalle que manda el backend tiene prioridad', () {
      final opciones = RequestOptions();
      final rechazo = DioException(
        requestOptions: opciones,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: opciones,
          statusCode: 401,
          data: {'detail': 'Correo o contraseña incorrectos'},
        ),
      );
      expect(mensajeDeError(rechazo), 'Correo o contraseña incorrectos');
    });
  });
}
