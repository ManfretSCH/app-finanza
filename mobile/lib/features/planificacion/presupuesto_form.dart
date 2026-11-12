import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alta de un presupuesto, o cambio de límite si se pasa [presupuesto].
///
/// [categoriasOcupadas] son las que ya tienen presupuesto ese mes: no se
/// ofrecen, porque el servidor rechazaría un segundo límite para la misma.
Future<void> abrirFormularioPresupuesto(
  BuildContext context,
  WidgetRef ref, {
  required DateTime mes,
  Presupuesto? presupuesto,
  Set<int> categoriasOcupadas = const {},
}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormularioPresupuesto(
      mes: mes,
      presupuesto: presupuesto,
      categoriasOcupadas: categoriasOcupadas,
    ),
  );
  if (guardado ?? false) refrescarPresupuestos(ref);
}

class _FormularioPresupuesto extends ConsumerStatefulWidget {
  const _FormularioPresupuesto({
    required this.mes,
    required this.categoriasOcupadas,
    this.presupuesto,
  });

  final DateTime mes;
  final Presupuesto? presupuesto;
  final Set<int> categoriasOcupadas;

  @override
  ConsumerState<_FormularioPresupuesto> createState() => _FormularioPresupuestoState();
}

class _FormularioPresupuestoState extends ConsumerState<_FormularioPresupuesto> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _limite;
  int? _categoriaId;
  bool _cargando = false;
  String? _error;

  bool get _esEdicion => widget.presupuesto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.presupuesto;
    _limite = TextEditingController(text: p == null ? '' : p.limite.toStringAsFixed(0));
    _categoriaId = p?.categoriaId;
  }

  @override
  void dispose() {
    _limite.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(presupuestosRepositoryProvider);
      final limite = double.parse(_limite.text.replaceAll(',', '.'));
      if (_esEdicion) {
        await repo.editar(widget.presupuesto!.id, limite: limite);
      } else {
        await repo.crear(
          categoriaId: _categoriaId!,
          mes: widget.mes.month,
          anio: widget.mes.year,
          limite: limite,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libres = (ref.watch(categoriasProvider).value ?? <Categoria>[])
        .where((c) => c.tipo == TipoMovimiento.gasto)
        .where((c) => !widget.categoriasOcupadas.contains(c.id))
        .toList();
    final sinCategoriasLibres = !_esEdicion && libres.isEmpty;

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
              Text(
                _esEdicion ? 'Cambiar el límite' : 'Nuevo presupuesto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Límite de gasto para ${nombreMesYAnio(widget.mes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              if (_esEdicion)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: Color(widget.presupuesto!.categoria.colorEntero),
                  ),
                  title: Text(widget.presupuesto!.categoria.nombre),
                  subtitle: Text(
                    'Llevás gastado ${formatearMonto(widget.presupuesto!.gastado)}',
                  ),
                )
              else if (sinCategoriasLibres)
                const Text('Todas tus categorías de gasto ya tienen presupuesto este mes.')
              else
                DropdownButtonFormField<int>(
                  initialValue: _categoriaId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: libres
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                  validator: (v) => v == null ? 'Elige una categoría' : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limite,
                enabled: !sinCategoriasLibres,
                autofocus: _esEdicion,
                decoration: const InputDecoration(
                  labelText: 'Límite mensual',
                  suffixText: 'PYG',
                  helperText: 'Te avisamos al llegar al 80 % y al 100 %',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Ingresa un número válido';
                  if (n <= 0) return 'El límite debe ser mayor a cero';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _cargando || sinCategoriasLibres ? null : _guardar,
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
