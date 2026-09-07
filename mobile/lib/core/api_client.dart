import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direccion del backend que se fija al compilar.
///
/// Se pasa con --dart-define, por ejemplo:
///   flutter build apk --release --dart-define=API_URL=http://192.168.0.5:8000/api/v1
///
/// Hace falta para repartir un APK: un telefono real no llega a "localhost" ni
/// a 10.0.2.2, tiene que apuntar a la IP de la maquina donde corre el backend.
const _urlDefinidaAlCompilar = String.fromEnvironment('API_URL');

/// Decide contra que servidor habla la app.
///
/// Esta separada de [urlBase] para poder probarla con entradas explicitas, sin
/// depender de con que banderas se compilo ni en que plataforma corre.
///
/// Si no se definio ninguna direccion al compilar se usa la de desarrollo. El
/// emulador de Android no puede usar "localhost": ese nombre apunta al propio
/// emulador. 10.0.2.2 es el alias que Android usa para la maquina anfitriona.
String resolverUrlBase({required String definidaAlCompilar, required bool esAndroid}) {
  if (definidaAlCompilar.isNotEmpty) return definidaAlCompilar;
  return esAndroid ? 'http://10.0.2.2:8000/api/v1' : 'http://localhost:8000/api/v1';
}

/// Direccion del backend con la que se arma el cliente HTTP.
String get urlBase => resolverUrlBase(
      definidaAlCompilar: _urlDefinidaAlCompilar,
      esAndroid: Platform.isAndroid,
    );

/// Cliente HTTP con el token adjuntado automaticamente en cada pedido.
class ApiClient {
  ApiClient(this._almacenamiento) {
    dio = Dio(
      BaseOptions(
        baseUrl: urlBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opciones, siguiente) async {
          final token = await _almacenamiento.read(key: _claveToken);
          if (token != null) {
            opciones.headers['Authorization'] = 'Bearer $token';
          }
          siguiente.next(opciones);
        },
      ),
    );
  }

  static const _claveToken = 'access_token';

  final FlutterSecureStorage _almacenamiento;
  late final Dio dio;

  /// El token se guarda cifrado (Keychain en iOS, EncryptedSharedPreferences en Android).
  Future<void> guardarToken(String token) =>
      _almacenamiento.write(key: _claveToken, value: token);

  Future<String?> leerToken() => _almacenamiento.read(key: _claveToken);

  Future<void> borrarToken() => _almacenamiento.delete(key: _claveToken);
}

/// Traduce un error de red en un mensaje que se le puede mostrar al usuario.
String mensajeDeError(Object error) {
  if (error is DioException) {
    final detalle = error.response?.data;
    if (detalle is Map && detalle['detail'] is String) {
      return detalle['detail'] as String;
    }
    if (detalle is Map && detalle['detail'] is List) {
      return 'Revisa los datos ingresados';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con el servidor. Verifica que este encendido.';
    }
  }
  return 'Ocurrio un error inesperado';
}
