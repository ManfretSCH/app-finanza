// Al abrir la app se recupera la sesion con el token guardado. Antes, cualquier
// error borraba el token: si el servidor estaba dormido o no habia conexion, el
// usuario perdia la sesion y tenia que escribir la contrasena de nuevo.

import 'dart:typed_data';

import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reemplaza la red: cada pedido se contesta con lo que diga la prueba.
class ServidorFalso implements HttpClientAdapter {
  ServidorFalso(this.responder);

  final ResponseBody Function(RequestOptions pedido) responder;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      responder(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody json(String cuerpo, int estado) => ResponseBody.fromString(
      cuerpo,
      estado,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late ApiClient api;
  late AuthRepository auth;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'token-guardado'});
    api = ApiClient(const FlutterSecureStorage());
    auth = AuthRepository(api);
  });

  test('con el token vigente se recupera el usuario', () async {
    api.dio.httpClientAdapter =
        ServidorFalso((_) => json('{"id": 1, "email": "ana@x.com", "nombre": "Ana"}', 200));

    final usuario = await auth.usuarioActual();

    expect(usuario?.nombre, 'Ana');
    expect(await api.leerToken(), 'token-guardado');
  });

  test('si el servidor rechaza el token, se borra y hay que iniciar sesión', () async {
    api.dio.httpClientAdapter = ServidorFalso(
      (_) => json('{"detail": "Credenciales inválidas o sesión vencida"}', 401),
    );

    expect(await auth.usuarioActual(), isNull);
    expect(await api.leerToken(), isNull);
  });

  test('si no hay conexión o el servidor no contesta a tiempo, el token se conserva', () async {
    for (final tipo in [DioExceptionType.connectionError, DioExceptionType.receiveTimeout]) {
      api.dio.httpClientAdapter = ServidorFalso(
        (pedido) => throw DioException(requestOptions: pedido, type: tipo),
      );

      await expectLater(auth.usuarioActual(), throwsA(isA<DioException>()));
      expect(await api.leerToken(), 'token-guardado', reason: '$tipo');
    }
  });

  test('si el servidor falla por otra cosa, el token también se conserva', () async {
    api.dio.httpClientAdapter = ServidorFalso((_) => json('{"detail": "Error interno"}', 500));

    await expectLater(auth.usuarioActual(), throwsA(isA<DioException>()));
    expect(await api.leerToken(), 'token-guardado');
  });
}
