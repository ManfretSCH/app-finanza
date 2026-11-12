import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';

/// Llamadas al módulo de presupuestos del backend (RF-004).
class PresupuestosRepository {
  PresupuestosRepository(this._api);

  final ApiClient _api;

  Future<List<Presupuesto>> listar({required int mes, required int anio}) async {
    final r = await _api.dio.get<List<dynamic>>(
      '/budgets',
      queryParameters: {'mes': mes, 'anio': anio},
    );
    return r.data!.map((j) => Presupuesto.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required int categoriaId,
    required int mes,
    required int anio,
    required double limite,
  }) =>
      _api.dio.post<void>('/budgets', data: {
        'category_id': categoriaId,
        'mes': mes,
        'anio': anio,
        'limite': limite.toStringAsFixed(2),
      });

  Future<void> editar(int id, {required double limite}) =>
      _api.dio.patch<void>('/budgets/$id', data: {'limite': limite.toStringAsFixed(2)});

  Future<void> eliminar(int id) => _api.dio.delete<void>('/budgets/$id');

  /// Repite en el mes indicado los límites del mes anterior. Devuelve cuántos copió.
  Future<int> copiarMesAnterior({required int mes, required int anio}) async {
    final r = await _api.dio.post<Map<String, dynamic>>(
      '/budgets/copiar',
      data: {'mes': mes, 'anio': anio},
    );
    return r.data!['copiados'] as int;
  }
}
