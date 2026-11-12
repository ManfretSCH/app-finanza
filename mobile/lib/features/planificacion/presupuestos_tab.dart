import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';
import 'package:app_finanzas/features/informes/informes_screen.dart';
import 'package:app_finanzas/features/planificacion/presupuesto_form.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Casos de uso del diagrama 04: Crear, Editar y Ver presupuestos, Ver
/// progreso y Recibir alertas.
class PresupuestosTab extends ConsumerWidget {
  const PresupuestosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presupuestos = ref.watch(presupuestosProvider);
    final mes = ref.watch(mesSeleccionadoProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Etiqueta propia: hay varios botones flotantes en la app a la vez.
        heroTag: 'nuevo-presupuesto',
        onPressed: () => abrirFormularioPresupuesto(
          context,
          ref,
          mes: mes,
          categoriasOcupadas: {...?presupuestos.value?.map((p) => p.categoriaId)},
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo presupuesto'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => refrescarPresupuestos(ref),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            const SelectorDeMes(),
            presupuestos.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => EstadoError(
                mensaje: mensajeDeError(e),
                alReintentar: () => refrescarPresupuestos(ref),
              ),
              data: (lista) => lista.isEmpty
                  ? _SinPresupuestos(mes: mes)
                  : Column(
                      children: [
                        _Resumen(presupuestos: lista),
                        for (final p in lista) _TarjetaPresupuesto(presupuesto: p),
                        TextButton.icon(
                          onPressed: () => _copiarDelMesAnterior(context, ref, mes),
                          icon: const Icon(Icons.content_copy, size: 18),
                          label: const Text('Copiar los que falten del mes anterior'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Color colorDePresupuesto(BuildContext context, Presupuesto p) => switch (p.alerta) {
      AlertaPresupuesto.limite => Theme.of(context).colorScheme.error,
      AlertaPresupuesto.atencion => colorAtencion,
      null => Theme.of(context).colorScheme.primary,
    };

Future<void> _copiarDelMesAnterior(BuildContext context, WidgetRef ref, DateTime mes) async {
  try {
    final copiados = await ref
        .read(presupuestosRepositoryProvider)
        .copiarMesAnterior(mes: mes.month, anio: mes.year);
    refrescarPresupuestos(ref);
    if (!context.mounted) return;
    mostrarAviso(
      context,
      switch (copiados) {
        0 => 'No había nada nuevo para copiar del mes anterior.',
        1 => 'Se copió 1 presupuesto del mes anterior.',
        _ => 'Se copiaron $copiados presupuestos del mes anterior.',
      },
    );
  } catch (e) {
    if (context.mounted) mostrarAviso(context, mensajeDeError(e));
  }
}

class _SinPresupuestos extends ConsumerWidget {
  const _SinPresupuestos({required this.mes});

  final DateTime mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const EstadoVacio(
          icono: Icons.pie_chart_outline,
          titulo: 'Sin presupuestos este mes',
          detalle: 'Poné un límite de gasto por categoría y la app te avisa '
              'cuando llegues al 80 % y al 100 %.',
        ),
        OutlinedButton.icon(
          onPressed: () => _copiarDelMesAnterior(context, ref, mes),
          icon: const Icon(Icons.content_copy),
          label: const Text('Copiar del mes anterior'),
        ),
      ],
    );
  }
}

/// Cuánto se gastó en total contra lo presupuestado en el mes.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.presupuestos});

  final List<Presupuesto> presupuestos;

  @override
  Widget build(BuildContext context) {
    final limite = presupuestos.fold<double>(0, (s, p) => s + p.limite);
    final gastado = presupuestos.fold<double>(0, (s, p) => s + p.gastado);
    final conAlerta = presupuestos.where((p) => p.alerta != null).length;
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: tema.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastado de lo presupuestado', style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              '${formatearMonto(gastado)} de ${formatearMonto(limite)}',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: limite == 0 ? 0 : (gastado / limite).clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (conAlerta > 0) ...[
              const SizedBox(height: 10),
              Text(
                conAlerta == 1
                    ? '1 categoría pasó el 80 % de su límite'
                    : '$conAlerta categorías pasaron el 80 % de su límite',
                style: tema.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaPresupuesto extends ConsumerWidget {
  const _TarjetaPresupuesto({required this.presupuesto});

  final Presupuesto presupuesto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = presupuesto;
    final color = colorDePresupuesto(context, p);
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _acciones(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: Color(p.categoria.colorEntero)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p.categoria.nombre, style: tema.textTheme.titleMedium)),
                  Text(
                    p.porcentajeTexto,
                    style: tema.textTheme.titleMedium?.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (p.porcentaje / 100).clamp(0, 1).toDouble(),
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatearMonto(p.gastado)} de ${formatearMonto(p.limite)}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    p.excedido
                        ? 'Te pasaste ${formatearMonto(-p.disponible)}'
                        : 'Quedan ${formatearMonto(p.disponible)}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: p.excedido ? color : null,
                      fontWeight: p.excedido ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              if (p.alerta != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      switch (p.alerta!) {
                        AlertaPresupuesto.atencion => 'Ya usaste más del 80 % del límite',
                        AlertaPresupuesto.limite when p.excedido => 'Superaste el límite',
                        AlertaPresupuesto.limite => 'Llegaste al límite',
                      },
                      style: tema.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acciones(BuildContext context, WidgetRef ref) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Cambiar el límite'),
              onTap: () => Navigator.of(context).pop('editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              subtitle: const Text('Los gastos registrados no se tocan'),
              onTap: () => Navigator.of(context).pop('eliminar'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (accion == null || !context.mounted) return;

    if (accion == 'editar') {
      await abrirFormularioPresupuesto(
        context,
        ref,
        mes: DateTime(presupuesto.anio, presupuesto.mes),
        presupuesto: presupuesto,
      );
      return;
    }

    final confirmado = await confirmar(
      context,
      titulo: 'Eliminar presupuesto',
      mensaje: 'Se borra el límite de ${presupuesto.categoria.nombre} para este mes. '
          'Los gastos ya registrados se conservan.',
    );
    if (!confirmado) return;
    try {
      await ref.read(presupuestosRepositoryProvider).eliminar(presupuesto.id);
      refrescarPresupuestos(ref);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, mensajeDeError(e));
    }
  }
}
