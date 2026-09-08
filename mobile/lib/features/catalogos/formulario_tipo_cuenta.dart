import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/tipo_cuenta.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> abrirFormularioTipoCuenta(
  BuildContext context,
  WidgetRef ref, {
  TipoCuenta? tipo,
}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormularioTipoCuenta(tipo: tipo),
  );
  if (guardado ?? false) refrescarCatalogos(ref);
}

class _FormularioTipoCuenta extends ConsumerStatefulWidget {
  const _FormularioTipoCuenta({this.tipo});

  final TipoCuenta? tipo;

  @override
  ConsumerState<_FormularioTipoCuenta> createState() => _FormularioTipoCuentaState();
}

class _FormularioTipoCuentaState extends ConsumerState<_FormularioTipoCuenta> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  bool _cargando = false;
  String? _error;

  bool get _esEdicion => widget.tipo != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.tipo?.nombre ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(tiposCuentaRepositoryProvider);
      if (_esEdicion) {
        await repo.editar(widget.tipo!.id, nombre: _nombre.text.trim());
      } else {
        await repo.crear(nombre: _nombre.text.trim(), icono: 'account_balance_wallet');
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
            Text(
              _esEdicion ? 'Editar tipo de cuenta' : 'Nuevo tipo de cuenta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Por ejemplo: billetera virtual, cuenta en dólares, préstamo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
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
