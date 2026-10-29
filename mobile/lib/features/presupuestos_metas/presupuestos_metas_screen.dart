import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PresupuestosMetasScreen extends ConsumerWidget {
  const PresupuestosMetasScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref){
    final month=ref.watch(mesSeleccionadoProvider);
    return DefaultTabController(length:2,child:Scaffold(
      appBar:AppBar(title:const Text('Planificación'),bottom:const TabBar(tabs:[
        Tab(icon:Icon(Icons.pie_chart_outline),text:'Presupuestos'),
        Tab(icon:Icon(Icons.savings_outlined),text:'Metas'),
      ])),
      body:TabBarView(children:[
        _Budgets(month:month,data:ref.watch(presupuestosProvider)),
        _Goals(data:ref.watch(metasProvider)),
      ]),
    ));
  }
}
class _Budgets extends ConsumerWidget {
 const _Budgets({required this.month,required this.data});
 final DateTime month; final AsyncValue<List<Presupuesto>> data;
 @override Widget build(BuildContext context,WidgetRef ref)=>Column(children:[
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
   IconButton(onPressed:()=>ref.read(mesSeleccionadoProvider.notifier).mover(-1),icon:const Icon(Icons.chevron_left)),
   Text(nombreMesYAnio(month),style:Theme.of(context).textTheme.titleMedium),
   IconButton(onPressed:()=>ref.read(mesSeleccionadoProvider.notifier).mover(1),icon:const Icon(Icons.chevron_right)),
  ]),
  Expanded(child:data.when(
   loading:()=>const Center(child:CircularProgressIndicator()),
   error:(e,_)=>EstadoError(mensaje:mensajeDeError(e),alReintentar:()=>ref.invalidate(presupuestosProvider)),
   data:(items)=>items.isEmpty?const EstadoVacio(icono:Icons.pie_chart_outline,titulo:'Sin presupuestos',detalle:'Define límites mensuales para controlar tus gastos.')
    :RefreshIndicator(onRefresh:()async=>ref.invalidate(presupuestosProvider),child:ListView(children:items.map((p)=>_BudgetCard(p)).toList())),
  )),
  SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(onPressed:()=>_budgetDialog(context,ref,month),icon:const Icon(Icons.add),label:const Text('Agregar presupuesto')))),
 ]);
}
class _BudgetCard extends ConsumerWidget {
 const _BudgetCard(this.p); final Presupuesto p;
 @override Widget build(BuildContext context,WidgetRef ref){
  final alert=p.alerta; final color=alert=='limite'?Theme.of(context).colorScheme.error:alert=='atencion'?Colors.orange:Theme.of(context).colorScheme.primary;
  return Card(child:ListTile(title:Text(p.categoria?.nombre??'Categoría'),subtitle:Padding(padding:const EdgeInsets.only(top:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    LinearProgressIndicator(value:(p.porcentaje/100).clamp(0,1).toDouble(),color:color),
    const SizedBox(height:6),Text(formatearMonto(p.gastado)+' de '+formatearMonto(p.limite)),
    if(alert!=null) Text(alert=='limite'?'Superaste el límite':'Alcanzaste el 80 %',style:TextStyle(color:color)),
  ])),trailing:PopupMenuButton<String>(onSelected:(v)async{
   if(v=='editar')await _budgetDialog(context,ref,DateTime(p.anio,p.mes),item:p);
   if(v=='eliminar'){await ref.read(presupuestosRepositoryProvider).eliminar(p.id);ref.invalidate(presupuestosProvider);}
  },itemBuilder:(_)=>const [PopupMenuItem(value:'editar',child:Text('Editar límite')),PopupMenuItem(value:'eliminar',child:Text('Eliminar'))]));
 }
}
class _Goals extends ConsumerWidget {
 const _Goals({required this.data}); final AsyncValue<List<MetaAhorro>> data;
 @override Widget build(BuildContext context,WidgetRef ref)=>Column(children:[
  Expanded(child:data.when(loading:()=>const Center(child:CircularProgressIndicator()),
   error:(e,_)=>EstadoError(mensaje:mensajeDeError(e),alReintentar:()=>ref.invalidate(metasProvider)),
   data:(items)=>items.isEmpty?const EstadoVacio(icono:Icons.savings_outlined,titulo:'Sin metas de ahorro',detalle:'Crea una meta y registra tu progreso.')
   :RefreshIndicator(onRefresh:()async=>ref.invalidate(metasProvider),child:ListView(children:items.map((g)=>_GoalCard(g)).toList())))),
  SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:FilledButton.icon(onPressed:()=>_goalDialog(context,ref),icon:const Icon(Icons.add),label:const Text('Crear meta')))),
 ]);
}
class _GoalCard extends ConsumerWidget {
 const _GoalCard(this.g); final MetaAhorro g;
 @override Widget build(BuildContext context,WidgetRef ref)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
  Row(children:[Expanded(child:Text(g.nombre,style:Theme.of(context).textTheme.titleMedium)),if(g.estado=='completada')const Chip(label:Text('Completada')),if(g.activa)PopupMenuButton<String>(onSelected:(v)async{
   if(v=='progreso')await _goalDialog(context,ref,item:g);
   if(v=='cancelar'){await ref.read(metasRepositoryProvider).editar(g.id,estado:'cancelada');ref.invalidate(metasProvider);}
   if(v=='eliminar'){if(await confirmar(context,titulo:'Eliminar meta',mensaje:'Se eliminará esta meta.')){await ref.read(metasRepositoryProvider).eliminar(g.id);ref.invalidate(metasProvider);}}
  },itemBuilder:(_)=>const [PopupMenuItem(value:'progreso',child:Text('Actualizar progreso')),PopupMenuItem(value:'cancelar',child:Text('Cancelar meta')),PopupMenuItem(value:'eliminar',child:Text('Eliminar'))])]),
  if(g.descripcion?.isNotEmpty??false)Text(g.descripcion!),
  Text('Objetivo: '+formatearMonto(g.montoObjetivo)+' · '+formatearFecha(g.fechaObjetivo)),
  const SizedBox(height:10),LinearProgressIndicator(value:g.progreso/100),
  const SizedBox(height:6),Text(formatearMonto(g.montoActual)+' ahorrados · '+g.progreso.toStringAsFixed(0)+'%'),
 ])));
}

Future<void> _budgetDialog(BuildContext context,WidgetRef ref,DateTime mes,{Presupuesto? item}) async {
 final cats=(ref.read(categoriasProvider).valueOrNull??<Categoria>[]).where((c)=>c.tipo==TipoMovimiento.gasto).toList();
 if(item==null&&cats.isEmpty){mostrarAviso(context,'Primero agrega una categoría de gasto.');return;}
 final amount=TextEditingController(text:item?.limite.toStringAsFixed(0)??'');
 int? cat=item?.categoriaId??(cats.isEmpty?null:cats.first.id);
 final key=GlobalKey<FormState>();
 final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>AlertDialog(
  title:Text(item==null?'Nuevo presupuesto':'Editar presupuesto'),
  content:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(item==null)DropdownButtonFormField<int>(initialValue:cat,decoration:const InputDecoration(labelText:'Categoría'),items:cats.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.nombre))).toList(),onChanged:(v)=>setState(()=>cat=v)),
   TextFormField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Límite mensual',suffixText:'PYG'),validator:(v){final n=double.tryParse((v??'').replaceAll(',','.'));return n==null||n<=0?'Ingresa un monto válido':null;}),
  ])),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:(){if(key.currentState!.validate())Navigator.pop(ctx,true);},child:const Text('Guardar'))],
 )));
 if(ok??false){final n=double.parse(amount.text.replaceAll(',','.'));if(item==null){await ref.read(presupuestosRepositoryProvider).crear(categoriaId:cat!,mes:mes.month,anio:mes.year,limite:n);}else{await ref.read(presupuestosRepositoryProvider).editar(item.id,n);}ref.invalidate(presupuestosProvider);}
 amount.dispose();
}
Future<void> _goalDialog(BuildContext context,WidgetRef ref,{MetaAhorro? item}) async {
 final name=TextEditingController(text:item?.nombre??'');final target=TextEditingController(text:item?.montoObjetivo.toStringAsFixed(0)??'');final saved=TextEditingController(text:item?.montoActual.toStringAsFixed(0)??'');final desc=TextEditingController(text:item?.descripcion??'');
 DateTime date=item?.fechaObjetivo??DateTime.now().add(const Duration(days:90));final key=GlobalKey<FormState>();
 final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>AlertDialog(
  title:Text(item==null?'Nueva meta':'Actualizar progreso'),
  content:Form(key:key,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
   if(item==null)...[
    TextFormField(controller:name,decoration:const InputDecoration(labelText:'Nombre'),validator:(v)=>(v==null||v.trim().isEmpty)?'Ingresa un nombre':null),
    TextFormField(controller:desc,decoration:const InputDecoration(labelText:'Descripción (opcional)')),
    TextFormField(controller:target,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Monto objetivo',suffixText:'PYG'),validator:(v){final n=double.tryParse((v??'').replaceAll(',','.'));return n==null||n<=0?'Ingresa un monto válido':null;}),
    ListTile(title:const Text('Fecha objetivo'),subtitle:Text(formatearFecha(date)),onTap:()async{final d=await showDatePicker(context:ctx,initialDate:date,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:3650)));if(d!=null)setState(()=>date=d);}),
   ],
   TextFormField(controller:saved,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:item==null?'Ya ahorrado':'Total ahorrado',suffixText:'PYG'),validator:(v){if(item==null&&(v??'').trim().isEmpty)return null;final n=double.tryParse((v??'').replaceAll(',','.'));return n==null||n<0?'Ingresa un monto válido':null;}),
  ]))),
  actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:(){if(key.currentState!.validate())Navigator.pop(ctx,true);},child:const Text('Guardar'))],
 )));
 if(ok??false){final n=double.tryParse(saved.text.replaceAll(',','.'))??0;if(item==null){await ref.read(metasRepositoryProvider).crear(nombre:name.text.trim(),descripcion:desc.text.trim().isEmpty?null:desc.text.trim(),objetivo:double.parse(target.text.replaceAll(',','.')),actual:n,fecha:date);}else{await ref.read(metasRepositoryProvider).editar(item.id,montoActual:n);}ref.invalidate(metasProvider);}
 name.dispose();target.dispose();saved.dispose();desc.dispose();
}
