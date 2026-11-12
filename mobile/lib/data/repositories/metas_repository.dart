import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';

/// Llamadas al módulo de metas de ahorro del backend (RF-005).
class MetasRepository {
  MetasRepository(this._api);

  final ApiClient _api;

  Future<List<MetaAhorro>> listar() async {
    final r = await _api.dio.get<List<dynamic>>('/goals');
    return r.data!.map((j) => MetaAhorro.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required String nombre,
    required double objetivo,
    required DateTime fechaObjetivo,
    double ahorrado = 0,
    String? descripcion,
  }) =>
      _api.dio.post<void>('/goals', data: {
        'nombre': nombre,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
        'monto_objetivo': objetivo.toStringAsFixed(2),
        'monto_actual': ahorrado.toStringAsFixed(2),
        'fecha_objetivo': _soloFecha(fechaObjetivo),
      });

  Future<void> editar(
    int id, {
    required String nombre,
    required double objetivo,
    required double ahorrado,
    required DateTime fechaObjetivo,
    String? descripcion,
  }) =>
      _api.dio.patch<void>('/goals/$id', data: {
        'nombre': nombre,
        // Se manda siempre, incluso vacía, para poder borrar una descripción.
        'descripcion': (descripcion ?? '').isEmpty ? null : descripcion,
        'monto_objetivo': objetivo.toStringAsFixed(2),
        'monto_actual': ahorrado.toStringAsFixed(2),
        'fecha_objetivo': _soloFecha(fechaObjetivo),
      });

  /// Cancela la meta o la vuelve a activar.
  Future<void> cambiarEstado(int id, EstadoMeta estado) =>
      _api.dio.patch<void>('/goals/$id', data: {'estado': estado.valor});

  /// Suma plata a lo ya ahorrado y devuelve la meta actualizada.
  Future<MetaAhorro> aportar(int id, double monto) async {
    final r = await _api.dio.post<Map<String, dynamic>>(
      '/goals/$id/aportar',
      data: {'monto': monto.toStringAsFixed(2)},
    );
    return MetaAhorro.fromJson(r.data!);
  }

  Future<void> eliminar(int id) => _api.dio.delete<void>('/goals/$id');

  static String _soloFecha(DateTime f) => f.toIso8601String().split('T').first;
}
