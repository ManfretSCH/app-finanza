import 'package:app_finanzas/data/models/categoria.dart';
class Presupuesto {
  const Presupuesto({required this.id, required this.categoriaId, required this.anio, required this.mes, required this.limite, required this.gastado, required this.porcentaje, this.alerta, this.categoria});
  factory Presupuesto.fromJson(Map<String,dynamic> j) => Presupuesto(
    id:j['id'] as int, categoriaId:j['category_id'] as int, anio:j['anio'] as int, mes:j['mes'] as int,
    limite:double.parse(j['limite'].toString()), gastado:double.parse(j['gastado'].toString()),
    porcentaje:double.parse(j['porcentaje'].toString()), alerta:j['alerta'] as String?,
    categoria:j['categoria']==null?null:Categoria.fromJson(j['categoria'] as Map<String,dynamic>));
  final int id,categoriaId,anio,mes;
  final double limite,gastado,porcentaje;
  final String? alerta;
  final Categoria? categoria;
}