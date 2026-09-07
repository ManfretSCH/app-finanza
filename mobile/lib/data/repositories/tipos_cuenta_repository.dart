import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/tipo_cuenta.dart';

/// Llamadas al modulo de tipos de cuenta.
class TiposCuentaRepository {
  TiposCuentaRepository(this._api);

  final ApiClient _api;

  Future<List<TipoCuenta>> listar() async {
    final r = await _api.dio.get<List<dynamic>>('/account-types');
    return r.data!.map((j) => TipoCuenta.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> crear({required String nombre, required String icono}) =>
      _api.dio.post<void>('/account-types', data: {'nombre': nombre, 'icono': icono});

  Future<void> editar(int id, {required String nombre}) =>
      _api.dio.patch<void>('/account-types/$id', data: {'nombre': nombre});

  Future<void> eliminar(int id) => _api.dio.delete<void>('/account-types/$id');
}
