import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/movimiento_fijo.dart';

/// Llamadas al módulo de movimientos fijos.
class MovimientosFijosRepository {
  MovimientosFijosRepository(this._api);

  final ApiClient _api;

  Future<List<MovimientoFijo>> listar() async {
    final r = await _api.dio.get<List<dynamic>>('/recurring');
    return r.data!.map((j) => MovimientoFijo.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required int cuentaId,
    required int categoriaId,
    required TipoMovimiento tipo,
    required double monto,
    required int diaDelMes,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    String? descripcion,
  }) =>
      _api.dio.post<void>('/recurring', data: {
        'account_id': cuentaId,
        'category_id': categoriaId,
        'tipo': tipo.valor,
        'monto': monto.toStringAsFixed(2),
        'dia_del_mes': diaDelMes,
        'fecha_inicio': _soloFecha(fechaInicio),
        'fecha_fin': ?_soloFechaOpcional(fechaFin),
        'descripcion': (descripcion ?? '').isEmpty ? null : descripcion,
      });

  Future<void> editar(int id, {bool? activo}) =>
      _api.dio.patch<void>('/recurring/$id', data: {'activo': ?activo});

  Future<void> eliminar(int id) => _api.dio.delete<void>('/recurring/$id');

  /// Genera los movimientos que falten hasta hoy.
  ///
  /// Se llama al iniciar sesión. Es idempotente, así que llamarla de más no
  /// duplica nada. Devuelve cuántos se crearon.
  Future<int> ponerseAlDia() async {
    final r = await _api.dio.post<Map<String, dynamic>>('/recurring/run');
    return r.data!['generados'] as int;
  }

  static String _soloFecha(DateTime f) => f.toIso8601String().split('T').first;
  static String? _soloFechaOpcional(DateTime? f) => f == null ? null : _soloFecha(f);
}
