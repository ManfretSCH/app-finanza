import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Casos de uso "Ver cuentas", "Ver saldo" y "Crear cuenta" (RF-001).
class CuentasScreen extends ConsumerWidget {
  const CuentasScreen({super.key});

  static const _iconos = {
    TipoCuenta.ahorro: Icons.savings,
    TipoCuenta.corriente: Icons.account_balance,
    TipoCuenta.tarjeta: Icons.credit_card,
    TipoCuenta.efectivo: Icons.payments,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
      body: cuentas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoError(mensaje: mensajeDeError(e), alReintentar: () => ref.invalidate(cuentasProvider)),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              icono: Icons.account_balance_wallet_outlined,
              titulo: 'Todavia no tienes cuentas',
              detalle: 'Crea tu primera cuenta para empezar a registrar movimientos.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cuentasProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: lista.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _TotalGeneral(cuentas: lista);
                final cuenta = lista[i - 1];
                return ListTile(
                  leading: CircleAvatar(child: Icon(_iconos[cuenta.tipo])),
                  title: Text(cuenta.nombre),
                  subtitle: Text(cuenta.tipo.etiqueta),
                  trailing: Text(
                    formatearMonto(cuenta.saldoActual, cuenta.moneda),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _mostrarFormulario(BuildContext context, WidgetRef ref) async {
    final creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FormularioCuenta(),
    );
    if (creada ?? false) ref.invalidate(cuentasProvider);
  }
}

/// Suma de los saldos de todas las cuentas en la misma moneda.
class _TotalGeneral extends StatelessWidget {
  const _TotalGeneral({required this.cuentas});

  final List<Cuenta> cuentas;

  @override
  Widget build(BuildContext context) {
    final moneda = cuentas.first.moneda;
    // Sin conversion de monedas: solo se suma lo que comparte moneda.
    final total = cuentas.where((c) => c.moneda == moneda).fold<double>(
          0,
          (suma, c) => suma + c.saldoActual,
        );

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Saldo total', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              formatearMonto(total, moneda),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioCuenta extends ConsumerStatefulWidget {
  const _FormularioCuenta();

  @override
  ConsumerState<_FormularioCuenta> createState() => _FormularioCuentaState();
}

class _FormularioCuentaState extends ConsumerState<_FormularioCuenta> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _saldo = TextEditingController(text: '0');
  TipoCuenta _tipo = TipoCuenta.ahorro;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _saldo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(cuentasRepositoryProvider).crear(
            nombre: _nombre.text.trim(),
            tipo: _tipo,
            saldoInicial: double.parse(_saldo.text.replaceAll(',', '.')),
            moneda: 'PYG',
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nueva cuenta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TipoCuenta>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: TipoCuenta.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.etiqueta)))
                  .toList(),
              onChanged: (t) => setState(() => _tipo = t!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _saldo,
              decoration: const InputDecoration(labelText: 'Saldo inicial', suffixText: 'PYG'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null) return 'Ingresa un numero valido';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _cargando ? null : _guardar,
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
