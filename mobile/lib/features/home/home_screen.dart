import 'package:app_finanzas/features/cuentas/cuentas_screen.dart';
import 'package:app_finanzas/features/informes/informes_screen.dart';
import 'package:app_finanzas/features/perfil/perfil_screen.dart';
import 'package:app_finanzas/features/transacciones/transacciones_screen.dart';
import 'package:flutter/material.dart';

/// Pantalla principal con la navegacion inferior.
///
/// Cuentas y Movimientos son del Modulo 1, Informes del Modulo 3.
/// Presupuestos y Metas se agregan en el Modulo 2.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  static const _pantallas = [
    CuentasScreen(),
    TransaccionesScreen(),
    InformesScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indice, children: _pantallas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Cuentas',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Informes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
