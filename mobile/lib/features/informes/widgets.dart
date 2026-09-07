import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/data/models/informe.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Contenedor con titulo para cada bloque del informe.
class SeccionInforme extends StatelessWidget {
  const SeccionInforme({
    required this.titulo,
    required this.child,
    this.subtitulo,
    super.key,
  });

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitulo!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Una de las tres cifras grandes del encabezado: ingresos, gastos o balance.
class CifraDestacada extends StatelessWidget {
  const CifraDestacada({
    required this.etiqueta,
    required this.monto,
    required this.color,
    required this.icono,
    super.key,
  });

  final String etiqueta;
  final double monto;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              formatearMontoCompacto(monto),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grafico de barras con el gasto de cada dia del mes.
class GraficoDiario extends StatelessWidget {
  const GraficoDiario({required this.dias, super.key});

  final List<LineaDia> dias;

  @override
  Widget build(BuildContext context) {
    final maximo = dias.map((d) => d.gastos).fold<double>(0, (a, b) => a > b ? a : b);
    if (maximo == 0) {
      return const _SinDatos(mensaje: 'No hubo gastos este mes.');
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maximo * 1.15,
          alignment: BarChartAlignment.spaceBetween,
          barGroups: [
            for (var i = 0; i < dias.length; i++)
              BarChartGroupData(
                x: dias[i].fecha.day,
                barRods: [
                  BarChartRodData(
                    toY: dias[i].gastos,
                    color: colorGasto,
                    width: 6,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maximo,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // Un numero cada cinco dias: con 30 etiquetas no se leeria nada.
                getTitlesWidget: (valor, meta) {
                  final dia = valor.toInt();
                  if (dia != 1 && dia % 5 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$dia', style: Theme.of(context).textTheme.bodySmall),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (grupo, _, rod, _) => BarTooltipItem(
                'Dia ${grupo.x}\n${formatearMonto(rod.toY)}',
                TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Torta con el peso de cada categoria, mas la lista con los montos exactos.
class DistribucionPorCategoria extends StatelessWidget {
  const DistribucionPorCategoria({
    required this.lineas,
    required this.mensajeVacio,
    super.key,
  });

  final List<LineaCategoria> lineas;
  final String mensajeVacio;

  @override
  Widget build(BuildContext context) {
    if (lineas.isEmpty) return _SinDatos(mensaje: mensajeVacio);

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 45,
              sections: [
                for (final linea in lineas)
                  PieChartSectionData(
                    value: linea.total,
                    color: Color(linea.categoria.colorEntero),
                    radius: 32,
                    // La etiqueta solo entra si la porcion es grande.
                    showTitle: linea.porcentaje >= 8,
                    title: '${linea.porcentaje.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final linea in lineas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(linea.categoria.colorEntero),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    linea.categoria.nombre,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${linea.porcentaje.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatearMonto(linea.total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Barras de ingresos contra gastos, mes a mes.
class GraficoAnual extends StatelessWidget {
  const GraficoAnual({required this.meses, super.key});

  final List<LineaMes> meses;

  @override
  Widget build(BuildContext context) {
    final maximo = meses
        .map((m) => m.ingresos > m.gastos ? m.ingresos : m.gastos)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maximo == 0) {
      return const _SinDatos(mensaje: 'Todavia no hay movimientos este ano.');
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: BarChart(
            BarChartData(
              maxY: maximo * 1.15,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (final mes in meses)
                  BarChartGroupData(
                    x: mes.mes,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(toY: mes.ingresos, color: colorIngreso, width: 5),
                      BarChartRodData(toY: mes.gastos, color: colorGasto, width: 5),
                    ],
                  ),
              ],
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (valor, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        abreviaturaMes(valor.toInt()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (grupo, _, rod, indice) => BarTooltipItem(
                    '${abreviaturaMes(grupo.x)}\n'
                    '${indice == 0 ? "Ingresos" : "Gastos"}: ${formatearMonto(rod.toY)}',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Leyenda(color: colorIngreso, texto: 'Ingresos'),
            SizedBox(width: 20),
            _Leyenda(color: colorGasto, texto: 'Gastos'),
          ],
        ),
      ],
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
