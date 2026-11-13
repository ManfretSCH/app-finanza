import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Alta de una meta de ahorro, o edición si se pasa [meta].
Future<void> abrirFormularioMeta(BuildContext context, WidgetRef ref, {MetaAhorro? meta}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FormularioMeta(meta: meta),
  );
  if (guardado ?? false) ref.invalidate(metasProvider);
}

class _FormularioMeta extends ConsumerStatefulWidget {
  const _FormularioMeta({this.meta});

  final MetaAhorro? meta;

  @override
  ConsumerState<_FormularioMeta> createState() => _FormularioMetaState();
}

class _FormularioMetaState extends ConsumerState<_FormularioMeta> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _objetivo;
  late final TextEditingController _ahorrado;
  late DateTime _fechaObjetivo;
  bool _cargando = false;
  String? _error;

  bool get _esEdicion => widget.meta != null;

  @override
  void initState() {
    super.initState();
    final m = widget.meta;
    _nombre = TextEditingController(text: m?.nombre ?? '');
    _descripcion = TextEditingController(text: m?.descripcion ?? '');
    _objetivo = TextEditingController(text: m?.montoObjetivo.toStringAsFixed(0) ?? '');
    _ahorrado = TextEditingController(text: m?.montoActual.toStringAsFixed(0) ?? '');
    // Tres meses es un plazo razonable para arrancar; el usuario lo cambia.
    _fechaObjetivo = m?.fechaObjetivo ?? DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _objetivo.dispose();
    _ahorrado.dispose();
    super.dispose();
  }

  static double? _leerMonto(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final repo = ref.read(metasRepositoryProvider);
      final objetivo = _leerMonto(_objetivo.text)!;
      final ahorrado = _leerMonto(_ahorrado.text) ?? 0;
      if (_esEdicion) {
        await repo.editar(
          widget.meta!.id,
          nombre: _nombre.text.trim(),
          descripcion: _descripcion.text.trim(),
          objetivo: objetivo,
          ahorrado: ahorrado,
          fechaObjetivo: _fechaObjetivo,
        );
      } else {
        await repo.crear(
          nombre: _nombre.text.trim(),
          descripcion: _descripcion.text.trim(),
          objetivo: objetivo,
          ahorrado: ahorrado,
          fechaObjetivo: _fechaObjetivo,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    // Al editar una meta vencida su fecha queda en el pasado: tiene que
    // poder mostrarse en el calendario.
    final primera = _fechaObjetivo.isBefore(hoy) ? _fechaObjetivo : hoy;
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaObjetivo,
      firstDate: primera,
      lastDate: DateTime(hoy.year + 30),
      helpText: 'Para cuándo querés juntarlo',
    );
    if (elegida != null) setState(() => _fechaObjetivo = elegida);
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
                _esEdicion ? 'Editar meta' : 'Nueva meta de ahorro',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombre,
                autofocus: !_esEdicion,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  helperText: 'Por ejemplo: vacaciones, fondo de emergencia, una moto',
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcion,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _objetivo,
                decoration: const InputDecoration(
                  labelText: 'Cuánto querés juntar',
                  suffixText: 'PYG',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = _leerMonto(v ?? '');
                  if (n == null) return 'Ingresa un número válido';
                  if (n <= 0) return 'El objetivo debe ser mayor a cero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ahorrado,
                decoration: InputDecoration(
                  labelText: _esEdicion ? 'Total ahorrado' : 'Ya ahorrado (opcional)',
                  suffixText: 'PYG',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final n = _leerMonto(v!);
                  if (n == null) return 'Ingresa un número válido';
                  if (n < 0) return 'No puede ser negativo';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Fecha objetivo'),
                subtitle: Text(formatearFechaLarga(_fechaObjetivo)),
                trailing: const Icon(Icons.edit),
                onTap: _elegirFecha,
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
