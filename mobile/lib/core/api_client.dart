import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direccion del backend segun donde se ejecute la app.
///
/// El emulador de Android no puede usar "localhost": ese nombre apunta al
/// propio emulador. 10.0.2.2 es el alias que Android usa para la maquina anfitriona.
String get urlBase {
  if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
  return 'http://localhost:8000/api/v1';
}

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
