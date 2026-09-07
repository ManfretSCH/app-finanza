import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/transaccion.dart';

/// Llamadas al modulo de transacciones (RF-002).
class TransaccionesRepository {
  TransaccionesRepository(this._api);

  final ApiClient _api;

  Future<List<Transaccion>> listar({
    TipoMovimiento? tipo,
    int? categoriaId,
    int limite = 50,
  }) async {
    final r = await _api.dio.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {
        if (tipo != null) 'tipo': tipo.valor,
        'category_id': ?categoriaId,
        'limite': limite,
      },
    );
    return (r.data!['items'] as List<dynamic>)
        .map((j) => Transaccion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> registrar({
    required int cuentaId,
    required int categoriaId,
    required TipoMovimiento tipo,
    required double monto,
    required DateTime fecha,
    String? descripcion,
  }) =>
      _api.dio.post<void>('/transactions', data: {
        'account_id': cuentaId,
        'category_id': categoriaId,
        'tipo': tipo.valor,
        'monto': monto.toStringAsFixed(2),
        'fecha': fecha.toIso8601String().split('T').first,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      });

  Future<void> eliminar(int id) => _api.dio.delete<void>('/transactions/$id');
}
