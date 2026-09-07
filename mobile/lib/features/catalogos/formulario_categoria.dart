import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Paleta fija en lugar de un selector libre de color: asi las categorias
/// mantienen contraste suficiente en los graficos y en modo oscuro.
const _coloresDisponibles = [
  '#FF7043', '#EF5350', '#EC407A', '#AB47BC', '#5C6BC0',
  '#42A5F5', '#26C6DA', '#26A69A', '#66BB6A', '#9CCC65',
  '#FFA726', '#8D6E63', '#78909C', '#607D8B',
];

Future<void> abrirFormularioCategoria(
  BuildContext context,
  WidgetRef ref, {
  Categoria? categoria,
}) async {
  final guardada = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormularioCategoria(categoria: categoria),
  );
  if (guardada ?? false) refrescarCatalogos(ref);
}

class _FormularioCategoria extends ConsumerStatefulWidget {
  const _FormularioCategoria({this.categoria});

  final Categoria? categoria;

  @override
  ConsumerState<_FormularioCategoria> createState() => _FormularioCategoriaState();
}

class _FormularioCategoriaState extends ConsumerState<_FormularioCategoria> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late TipoMovimiento _tipo;
  late String _color;
  bool _cargando = false;
  String? _error;

  bool get _esEdicion => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.categoria?.nombre ?? '');
    _tipo = widget.categoria?.tipo ?? TipoMovimiento.gasto;
    _color = widget.categoria?.color ?? _coloresDisponibles.first;
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
      final repo = ref.read(categoriasRepositoryProvider);
      if (_esEdicion) {
        await repo.editar(widget.categoria!.id, nombre: _nombre.text.trim(), color: _color);
      } else {
        await repo.crear(nombre: _nombre.text.trim(), tipo: _tipo, color: _color);
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
      child: SingleChildScrollView(
        child: Form(
          key: _formulario,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _esEdicion ? 'Editar categoria' : 'Nueva categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              if (_esEdicion)
                // El tipo no se cambia despues: las transacciones ya cargadas
                // quedarian clasificadas al reves.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text('Categoria de ${_tipo.etiqueta.toLowerCase()}'),
                  subtitle: const Text('El tipo no se puede cambiar'),
                )
              else
                SegmentedButton<TipoMovimiento>(
                  segments: const [
                    ButtonSegment(value: TipoMovimiento.gasto, label: Text('Gasto')),
                    ButtonSegment(value: TipoMovimiento.ingreso, label: Text('Ingreso')),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final color in _coloresDisponibles)
                    GestureDetector(
                      onTap: () => setState(() => _color = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${color.substring(1)}', radix: 16)),
                          shape: BoxShape.circle,
                          border: _color == color
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: _color == color
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    ),
                ],
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
