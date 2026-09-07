import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/informe.dart';
import 'package:app_finanzas/features/informes/exportar_boton.dart';
import 'package:app_finanzas/features/informes/widgets.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Informes del mes (RF-006).
///
/// Responde, en este orden, las preguntas que se hace alguien mirando sus
/// finanzas: cuanto entro y salio, cuanto gasta por dia, en que se le va la
/// plata, de donde viene, y como viene el ano.
class InformesScreen extends ConsumerWidget {
  const InformesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumen = ref.watch(resumenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes'),
        actions: const [BotonExportar()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refrescarDatos(ref),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _SelectorDeMes(),
            resumen.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: EstadoError(
                  mensaje: mensajeDeError(e),
                  alReintentar: () => refrescarDatos(ref),
                ),
              ),
              data: (datos) => datos.sinDatos
                  ? const _MesSinMovimientos()
                  : Column(
                      children: [
                        _Encabezado(resumen: datos),
                        _PromedioDiario(resumen: datos),
                        const _GastoPorDia(),
                        const _DondeSeVaLaPlata(),
                        const _DeDondeVieneLaPlata(),
                        const _TendenciaDelAnio(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorDeMes extends ConsumerWidget {
  const _SelectorDeMes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesSeleccionadoProvider);
    final hoy = DateTime.now();
    final esMesActual = mes.year == hoy.year && mes.month == hoy.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => ref.read(mesSeleccionadoProvider.notifier).mover(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mes anterior',
          ),
          Text(
            nombreMesYAnio(mes),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            // No se puede avanzar mas alla del mes en curso.
            onPressed: esMesActual ? null : () => ref.read(mesSeleccionadoProvider.notifier).mover(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Mes siguiente',
          ),
        ],
      ),
    );
  }
}

class _MesSinMovimientos extends StatelessWidget {
  const _MesSinMovimientos();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: EstadoVacio(
        icono: Icons.insights_outlined,
        titulo: 'Sin movimientos en este mes',
        detalle: 'Registra ingresos y gastos para ver aca tus informes.',
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    final balancePositivo = resumen.balance >= 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Row(
          children: [
            CifraDestacada(
              etiqueta: 'Ingresos',
              monto: resumen.ingresos,
              color: colorIngreso,
              icono: Icons.arrow_downward,
            ),
            CifraDestacada(
              etiqueta: 'Gastos',
              monto: resumen.gastos,
              color: colorGasto,
              icono: Icons.arrow_upward,
            ),
            CifraDestacada(
              etiqueta: 'Balance',
              monto: resumen.balance,
              color: balancePositivo
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              icono: balancePositivo ? Icons.trending_up : Icons.trending_down,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromedioDiario extends StatelessWidget {
  const _PromedioDiario({required this.resumen});

  final ResumenMensual resumen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.today,
              size: 32,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gastas por dia', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    formatearMonto(resumen.promedioDiarioGasto),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Promedio sobre ${resumen.diasConsiderados} dias · '
                    '${resumen.cantidadMovimientos} movimientos',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _GastoPorDia extends ConsumerWidget {
  const _GastoPorDia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeccionInforme(
      titulo: 'Gasto dia por dia',
      subtitulo: 'Toca una barra para ver el monto exacto',
      child: ref.watch(porDiaProvider).when(
            loading: () => const _Cargando(),
            error: (e, _) => Text(mensajeDeError(e)),
            data: (dias) => GraficoDiario(dias: dias),
          ),
    );
  }
}

class _DondeSeVaLaPlata extends ConsumerWidget {
  const _DondeSeVaLaPlata();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeccionInforme(
      titulo: 'En que se va tu plata',
      subtitulo: 'Gastos del mes por categoria, de mayor a menor',
      child: ref.watch(gastosPorCategoriaProvider).when(
            loading: () => const _Cargando(),
            error: (e, _) => Text(mensajeDeError(e)),
            data: (lineas) => DistribucionPorCategoria(
              lineas: lineas,
              mensajeVacio: 'No registraste gastos este mes.',
            ),
          ),
    );
  }
}

class _DeDondeVieneLaPlata extends ConsumerWidget {
  const _DeDondeVieneLaPlata();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeccionInforme(
      titulo: 'De donde viene tu plata',
      subtitulo: 'Ingresos del mes por categoria',
      child: ref.watch(ingresosPorCategoriaProvider).when(
            loading: () => const _Cargando(),
            error: (e, _) => Text(mensajeDeError(e)),
            data: (lineas) => DistribucionPorCategoria(
              lineas: lineas,
              mensajeVacio: 'No registraste ingresos este mes.',
            ),
          ),
    );
  }
}

class _TendenciaDelAnio extends ConsumerWidget {
  const _TendenciaDelAnio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anio = ref.watch(mesSeleccionadoProvider).year;

    return SeccionInforme(
      titulo: 'Como viene el ano',
      subtitulo: 'Ingresos contra gastos, mes a mes, en $anio',
      child: ref.watch(tendenciaAnualProvider).when(
            loading: () => const _Cargando(),
            error: (e, _) => Text(mensajeDeError(e)),
            data: (meses) => GraficoAnual(meses: meses),
          ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 170,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
