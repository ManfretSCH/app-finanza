import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';

/// Llamadas al modulo de categorias (RF-003).
class CategoriasRepository {
  CategoriasRepository(this._api);

  final ApiClient _api;

  Future<List<Categoria>> listar({TipoMovimiento? tipo}) async {
    final r = await _api.dio.get<List<dynamic>>(
      '/categories',
      queryParameters: {if (tipo != null) 'tipo': tipo.valor},
    );
    return r.data!.map((j) => Categoria.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required String nombre,
    required TipoMovimiento tipo,
    required String color,
    String icono = 'category',
  }) =>
      _api.dio.post<void>('/categories', data: {
        'nombre': nombre,
        'tipo': tipo.valor,
        'icono': icono,
        'color': color,
      });

  Future<void> editar(int id, {String? nombre, String? color}) =>
      _api.dio.patch<void>('/categories/$id', data: {
        'nombre': ?nombre,
        'color': ?color,
      });

  Future<void> eliminar(int id) => _api.dio.delete<void>('/categories/$id');
}
