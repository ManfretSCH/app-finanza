import 'package:app_finanzas/features/planificacion/metas_tab.dart';
import 'package:app_finanzas/features/planificacion/presupuestos_tab.dart';
import 'package:flutter/material.dart';

/// Módulo 2: presupuestos mensuales (RF-004) y metas de ahorro (RF-005).
///
/// Están juntos porque los dos miran hacia adelante: cuánto se piensa gastar y
/// cuánto se quiere juntar. Los movimientos y los informes miran lo que ya pasó.
class PlanificacionScreen extends StatelessWidget {
  const PlanificacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planificación'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pie_chart_outline), text: 'Presupuestos'),
              Tab(icon: Icon(Icons.savings_outlined), text: 'Metas'),
            ],
          ),
        ),
        body: const TabBarView(children: [PresupuestosTab(), MetasTab()]),
      ),
    );
  }
}
