import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/informe.dart';

/// Llamadas al modulo de informes (RF-006).
class InformesRepository {
  InformesRepository(this._api);

  final ApiClient _api;

  Future<ResumenMensual> resumen({required int mes, required int anio}) async {
    final r = await _api.dio.get<Map<String, dynamic>>(
      '/reports/resumen',
      queryParameters: {'mes': mes, 'anio': anio},
    );
    return ResumenMensual.fromJson(r.data!);
  }

  Future<List<LineaCategoria>> porCategoria({
    required TipoMovimiento tipo,
    required int mes,
    required int anio,
  }) async {
    final r = await _api.dio.get<List<dynamic>>(
      '/reports/por-categoria',
      queryParameters: {'tipo': tipo.valor, 'mes': mes, 'anio': anio},
    );
    return r.data!.map((j) => LineaCategoria.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<LineaDia>> porDia({required int mes, required int anio}) async {
    final r = await _api.dio.get<List<dynamic>>(
      '/reports/por-dia',
      queryParameters: {'mes': mes, 'anio': anio},
    );
    return r.data!.map((j) => LineaDia.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<LineaMes>> porMes({required int anio}) async {
    final r = await _api.dio.get<List<dynamic>>(
      '/reports/por-mes',
      queryParameters: {'anio': anio},
    );
    return r.data!.map((j) => LineaMes.fromJson(j as Map<String, dynamic>)).toList();
  }
}
