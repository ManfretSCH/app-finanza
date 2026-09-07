import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/cuenta.dart';

/// Llamadas al modulo de cuentas (RF-001).
class CuentasRepository {
  CuentasRepository(this._api);

  final ApiClient _api;

  Future<List<Cuenta>> listar() async {
    final r = await _api.dio.get<List<dynamic>>('/accounts');
    return r.data!.map((j) => Cuenta.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Cuenta> crear({
    required String nombre,
    required int tipoId,
    required double saldoInicial,
    required String moneda,
  }) async {
    final r = await _api.dio.post<Map<String, dynamic>>(
      '/accounts',
      data: {
        'nombre': nombre,
        'account_type_id': tipoId,
        'saldo_inicial': saldoInicial.toStringAsFixed(2),
        'moneda': moneda,
      },
    );
    return Cuenta.fromJson(r.data!);
  }

  Future<void> editar(int id, {String? nombre, int? tipoId, bool? activa}) =>
      _api.dio.patch<void>('/accounts/$id', data: {
        'nombre': ?nombre,
        'account_type_id': ?tipoId,
        'activa': ?activa,
      });

  Future<void> eliminar(int id) => _api.dio.delete<void>('/accounts/$id');
}
