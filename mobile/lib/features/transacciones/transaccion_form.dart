import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:app_finanzas/features/planificacion/alerta_presupuesto.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lo que devuelve el formulario al guardar: alcanza para revisar el presupuesto.
typedef _MovimientoGuardado = ({TipoMovimiento tipo, int categoriaId, DateTime fecha});

/// Abre el formulario de movimientos y refresca los datos si se guardo algo.
///
/// Sin [movimiento] da de alta uno nuevo; con [movimiento] edita ese. Si lo
/// guardado es un gasto, avisa cuando su categoria llego al 80 % o al 100 %
/// del presupuesto del mes.
Future<void> abrirFormularioTransaccion(
  BuildContext context,
  WidgetRef ref, {
  Transaccion? movimiento,
}) async {
  final guardado = await showModalBottomSheet<_MovimientoGuardado>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormularioTransaccion(movimiento: movimiento),
  );
  if (guardado == null) return;
  refrescarDatos(ref);
  if (guardado.tipo == TipoMovimiento.gasto && context.mounted) {
    await avisarSiCorrespondePresupuesto(
      context,
      ref,
      categoriaId: guardado.categoriaId,
      fecha: guardado.fecha,
    );
  }
}

class _FormularioTransaccion extends ConsumerStatefulWidget {
  const _FormularioTransaccion({this.movimiento});

  final Transaccion? movimiento;

  @override
  ConsumerState<_FormularioTransaccion> createState() => _FormularioTransaccionState();
}

class _FormularioTransaccionState extends ConsumerState<_FormularioTransaccion> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _monto;
  late final TextEditingController _descripcion;

  late TipoMovimiento _tipo;
  late DateTime _fecha;
  int? _cuentaId;
  int? _categoriaId;
  bool _cargando = false;
  String? _error;

  bool get _esEdicion => widget.movimiento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.movimiento;
    // Al editar se precarga todo, incluido el tipo y la cuenta: cambiarlos es
    // justamente lo que permite pasar un movimiento de ingreso a gasto o
    // moverlo a otra cuenta sin tener que borrarlo y cargarlo de nuevo.
    _monto = TextEditingController(
      text: m == null ? '' : m.monto.toStringAsFixed(0),
    );
    _descripcion = TextEditingController(text: m?.descripcion ?? '');
    _tipo = m?.tipo ?? TipoMovimiento.gasto;
    _fecha = m?.fecha ?? DateTime.now();
    _cuentaId = m?.cuentaId;
    _categoriaId = m?.categoriaId;
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    if (_cuentaId == null || _categoriaId == null) {
      setState(() => _error = 'Elige la cuenta y la categoría');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(transaccionesRepositoryProvider);
      final monto = double.parse(_monto.text.replaceAll(',', '.'));
      if (_esEdicion) {
        await repo.editar(
          widget.movimiento!.id,
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId!,
          tipo: _tipo,
          monto: monto,
          fecha: _fecha,
          descripcion: _descripcion.text.trim(),
        );
      } else {
        await repo.registrar(
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId!,
          tipo: _tipo,
          monto: monto,
          fecha: _fecha,
          descripcion: _descripcion.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop((tipo: _tipo, categoriaId: _categoriaId!, fecha: _fecha));
      }
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _esEdicion ? 'Editar movimiento' : 'Nuevo movimiento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
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
                // Al editar no conviene abrir el teclado solo: el usuario
                // quizas viene a cambiar la categoria, no el monto.
                autofocus: !_esEdicion,
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Ingresa un número válido';
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
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categorias
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _categoriaId = v),
                validator: (v) => v == null ? 'Elige una categoría' : null,
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
                  labelText: 'Descripción',
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
