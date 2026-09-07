import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/usuario.dart';

/// Llamadas al modulo de autenticacion del backend (RF-007).
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<Usuario> registrar({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final r = await _api.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'nombre': nombre, 'email': email, 'password': password},
    );
    return _guardarSesion(r.data!);
  }

  Future<Usuario> iniciarSesion({required String email, required String password}) async {
    final r = await _api.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return _guardarSesion(r.data!);
  }

  Future<Usuario> _guardarSesion(Map<String, dynamic> datos) async {
    await _api.guardarToken(datos['access_token'] as String);
    return Usuario.fromJson(datos['usuario'] as Map<String, dynamic>);
  }

  /// Recupera la sesion guardada al abrir la app. Devuelve null si no hay token
  /// o si el token ya vencio.
  Future<Usuario?> usuarioActual() async {
    if (await _api.leerToken() == null) return null;
    try {
      final r = await _api.dio.get<Map<String, dynamic>>('/auth/me');
      return Usuario.fromJson(r.data!);
    } catch (_) {
      await _api.borrarToken();
      return null;
    }
  }

  /// Cerrar sesion es borrar el token del dispositivo: el JWT no se guarda en el servidor.
  Future<void> cerrarSesion() => _api.borrarToken();

  Future<void> cambiarPassword({required String actual, required String nueva}) =>
      _api.dio.post<void>(
        '/auth/change-password',
        data: {'password_actual': actual, 'password_nueva': nueva},
      );
}
