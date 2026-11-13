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

/// Cuanto se espera a que el servidor acepte la conexion.
///
/// Aunque el backend este dormido, en Render la conexion la atiende enseguida su
/// proxy, que retiene el pedido hasta que el servicio arranca. Por eso este tiempo
/// puede ser corto: si se agota, el servidor de verdad no esta al alcance.
const tiempoMaximoConexion = Duration(seconds: 30);

/// Cuanto se espera la respuesta una vez enviado el pedido.
///
/// El backend corre en la capa gratuita de Render, que lo apaga tras un rato sin
/// uso. El primer pedido que llega despues tiene que esperar a que vuelva a
/// arrancar: se midieron 42 segundos y a veces anda cerca de los dos minutos. Con
/// 10 segundos, como estaba antes, ese pedido fallaba siempre. Se deja algo de
/// margen por encima de los dos minutos que se le anuncian al usuario.
const tiempoMaximoRespuesta = Duration(seconds: 150);

/// Cliente HTTP con el token adjuntado automaticamente en cada pedido.
class ApiClient {
  ApiClient(this._almacenamiento) {
    dio = Dio(
      BaseOptions(
        baseUrl: urlBase,
        connectTimeout: tiempoMaximoConexion,
        receiveTimeout: tiempoMaximoRespuesta,
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
      return 'No se pudo conectar con el servidor. Verifica que esté encendido.';
    }
    // Hubo conexion pero la respuesta no llego a tiempo. Lo mas probable es que
    // el servidor siguiera arrancando, y como el arranque continua aunque este
    // pedido se haya cortado, al reintentar en un rato suele responder.
    if (error.type == DioExceptionType.receiveTimeout) {
      return 'El servidor tardó demasiado en responder. '
          'Puede que todavía se esté despertando: intenta de nuevo en un momento.';
    }
  }
  return 'Ocurrió un error inesperado';
}
