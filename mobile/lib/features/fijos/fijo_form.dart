import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alta de un gasto o ingreso fijo.
Future<void> abrirFormularioFijo(BuildContext context, WidgetRef ref) async {
  final creado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FormularioFijo(),
  );
  if (creado ?? false) refrescarFijos(ref);
}

class _FormularioFijo extends ConsumerStatefulWidget {
  const _FormularioFijo();

  @override
  ConsumerState<_FormularioFijo> createState() => _FormularioFijoState();
}

class _FormularioFijoState extends ConsumerState<_FormularioFijo> {
  final _formulario = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();

  TipoMovimiento _tipo = TipoMovimiento.gasto;
  int _diaDelMes = 1;
  // Por defecto arranca este mes: es lo que espera alguien que carga el
  // alquiler hoy, no que le genere movimientos de meses anteriores.
  DateTime _fechaInicio = DateTime(DateTime.now().year, DateTime.now().month);
  int? _cuentaId;
  int? _categoriaId;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(movimientosFijosRepositoryProvider).crear(
            cuentaId: _cuentaId!,
            categoriaId: _categoriaId!,
            tipo: _tipo,
            monto: double.parse(_monto.text.replaceAll(',', '.')),
            diaDelMes: _diaDelMes,
            fechaInicio: _fechaInicio,
            descripcion: _descripcion.text.trim(),
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
    final cuentas = ref.watch(cuentasProvider).value ?? <Cuenta>[];
    final categorias = (ref.watch(categoriasProvider).value ?? <Categoria>[])
        .where((c) => c.tipo == _tipo)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nuevo movimiento fijo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Se va a registrar solo todos los meses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              SegmentedButton<TipoMovimiento>(
                segments: const [
                  ButtonSegment(value: TipoMovimiento.gasto, label: Text('Gasto')),
                  ButtonSegment(value: TipoMovimiento.ingreso, label: Text('Ingreso')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() {
                  _tipo = s.first;
                  _categoriaId = null;
                }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _monto,
                decoration: const InputDecoration(labelText: 'Monto', suffixText: 'PYG'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Ingresa un número válido';
                  if (n <= 0) return 'El monto debe ser mayor a cero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  helperText: 'Por ejemplo: alquiler, internet, cuota del gimnasio',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _cuentaId,
                decoration: const InputDecoration(labelText: 'Cuenta'),
                items: cuentas
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _cuentaId = v),
                validator: (v) => v == null ? 'Elige una cuenta' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _categoriaId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categorias
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _categoriaId = v),
                validator: (v) => v == null ? 'Elige una categoría' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _diaDelMes,
                decoration: const InputDecoration(
                  labelText: 'Día del mes',
                  helperText: 'Si el mes no llega a ese día, se usa el último',
                ),
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('Día $d')),
                ],
                onChanged: (v) => setState(() => _diaDelMes = v!),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('Desde'),
                subtitle: Text(nombreMesYAnio(_fechaInicio)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: _fechaInicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    helpText: 'Desde qué mes se registra',
                  );
                  if (elegida != null) {
                    setState(() => _fechaInicio = DateTime(elegida.year, elegida.month, 1));
                  }
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
      ),
    );
  }
}
