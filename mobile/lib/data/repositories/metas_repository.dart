import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';
class MetasRepository {
  MetasRepository(this._api); final ApiClient _api;
  Future<List<MetaAhorro>> listar() async {
    final r=await _api.dio.get<List<dynamic>>('/goals');
    return r.data!.map((j)=>MetaAhorro.fromJson(j as Map<String,dynamic>)).toList();
  }
  Future<void> crear({required String nombre,String? descripcion,required double objetivo,required double actual,required DateTime fecha})=>
    _api.dio.post<void>('/goals',data:{'nombre':nombre,'descripcion':descripcion,'monto_objetivo':objetivo.toStringAsFixed(2),'monto_actual':actual.toStringAsFixed(2),'fecha_objetivo':fecha.toIso8601String().split('T').first});
  Future<void> editar(int id,{double? montoActual,String? estado})=>_api.dio.patch<void>('/goals/$id',data:{if(montoActual!=null)'monto_actual':montoActual.toStringAsFixed(2),if(estado!=null)'estado':estado});
  Future<void> eliminar(int id)=>_api.dio.delete<void>('/goals/$id');
}