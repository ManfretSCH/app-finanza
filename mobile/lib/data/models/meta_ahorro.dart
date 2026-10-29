class MetaAhorro {
  const MetaAhorro({required this.id,required this.nombre,required this.montoObjetivo,required this.montoActual,required this.fechaObjetivo,required this.estado,required this.progreso,this.descripcion});
  factory MetaAhorro.fromJson(Map<String,dynamic> j)=>MetaAhorro(
    id:j['id'] as int,nombre:j['nombre'] as String,descripcion:j['descripcion'] as String?,
    montoObjetivo:double.parse(j['monto_objetivo'].toString()),montoActual:double.parse(j['monto_actual'].toString()),
    fechaObjetivo:DateTime.parse(j['fecha_objetivo'] as String),estado:j['estado'] as String,progreso:double.parse(j['progreso'].toString()));
  final int id; final String nombre; final String? descripcion;
  final double montoObjetivo,montoActual,progreso; final DateTime fechaObjetivo; final String estado;
  bool get activa=>estado=='activa';
}