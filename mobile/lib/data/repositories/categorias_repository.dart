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
}
