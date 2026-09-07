import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abre el formulario de alta y refresca los datos si se registro algo.
Future<void> abrirFormularioTransaccion(BuildContext context, WidgetRef ref) async {
  final registrada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FormularioTransaccion(),
  );
  if (registrada ?? false) refrescarDatos(ref);
}

class _FormularioTransaccion extends ConsumerStatefulWidget {
  const _FormularioTransaccion();

  @override
  ConsumerState<_FormularioTransaccion> createState() => _FormularioTransaccionState();
}

class _FormularioTransaccionState extends ConsumerState<_FormularioTransaccion> {
  final _formulario = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();

  TipoMovimiento _tipo = TipoMovimiento.gasto;
  DateTime _fecha = DateTime.now();
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
    if (_cuentaId == null || _categoriaId == null) {
      setState(() => _error = 'Elige la cuenta y la categoria');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(transaccionesRepositoryProvider).registrar(
            cuentaId: _cuentaId!,
            categoriaId: _categoriaId!,
            tipo: _tipo,
            monto: double.parse(_monto.text.replaceAll(',', '.')),
            fecha: _fecha,
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
    // Solo se ofrecen las categorias que corresponden al tipo elegido:
    // no tiene sentido cargar un ingreso en la categoria "Transporte".
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
              SegmentedButton<TipoMovimiento>(
                segments: const [
                  ButtonSegment(
                    value: TipoMovimiento.gasto,
                    label: Text('Gasto'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: TipoMovimiento.ingreso,
                    label: Text('Ingreso'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() {
                  _tipo = s.first;
                  _categoriaId = null; // la categoria anterior ya no aplica
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
                  if (n == null) return 'Ingresa un numero valido';
                  if (n <= 0) return 'El monto debe ser mayor a cero';
                  return null;
                },
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
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: categorias
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _categoriaId = v),
                validator: (v) => v == null ? 'Elige una categoria' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha'),
                subtitle: Text(formatearFecha(_fecha)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (elegida != null) setState(() => _fecha = elegida);
                },
              ),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(
                  labelText: 'Descripcion',
                  helperText: 'Opcional',
                ),
                textCapitalization: TextCapitalization.sentences,
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
