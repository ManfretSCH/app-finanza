import 'package:app_finanzas/features/cuentas/cuentas_screen.dart';
import 'package:app_finanzas/features/informes/informes_screen.dart';
import 'package:app_finanzas/features/perfil/perfil_screen.dart';
import 'package:app_finanzas/features/planificacion/planificacion_screen.dart';
import 'package:app_finanzas/features/transacciones/transacciones_screen.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla principal con la navegacion inferior.
///
/// Cuentas y Movimientos son del Modulo 1, Planificacion (presupuestos y
/// metas) del Modulo 2 e Informes del Modulo 3.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _indice = 0;

  static const _pantallas = [
    CuentasScreen(),
    TransaccionesScreen(),
    InformesScreen(),
    PlanificacionScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Cuantos presupuestos de este mes pasaron el 80 %: se marca en la pestaña
    // para que el aviso se vea aunque el usuario no entre a Planificacion.
    final alertas = ref.watch(alertasPresupuestoProvider).value?.length ?? 0;

    return Scaffold(
      body: IndexedStack(index: _indice, children: _pantallas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Cuentas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Informes',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alertas > 0,
              label: Text('$alertas'),
              child: const Icon(Icons.savings_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: alertas > 0,
              label: Text('$alertas'),
              child: const Icon(Icons.savings),
            ),
            label: 'Planificación',
            tooltip: alertas > 0 ? 'Planificación: $alertas presupuestos en alerta' : null,
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
