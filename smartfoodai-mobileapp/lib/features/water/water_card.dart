import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'water_api.dart';

class WaterCard extends ConsumerStatefulWidget {
  final int refresh;
  const WaterCard({super.key, required this.refresh});
  @override
  ConsumerState<WaterCard> createState() => _WaterCardState();
}

class _WaterCardState extends ConsumerState<WaterCard> {
  static const _channel = MethodChannel('smartfoodai/timezone');
  late final WaterApi _api;
  WaterSummary? _summary;
  String? _error;
  bool _busy = false, _dialog = false;
  int _revision = 0;
  ({int amount, String key, String zone})? _pending;
  @override
  void initState() {
    super.initState();
    _api = WaterApi(ref.read(authProvider));
    _load();
  }

  @override
  void didUpdateWidget(covariant WaterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh && !_busy) _load();
  }

  @override
  void dispose() {
    _revision++;
    _api.dispose();
    super.dispose();
  }

  Future<String> _zone() async {
    final zone = await _channel.invokeMethod<String>('getTimeZone');
    if (zone == null || zone.isEmpty) {
      throw const ApiFailure('No pudimos leer la zona horaria de Android.');
    }
    return zone;
  }

  Future<void> _load() async {
    if (_busy) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = null;
      _summary = null;
    });
    try {
      final summary = await _api.get(await _zone());
      if (mounted && revision == _revision) setState(() => _summary = summary);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos cargar el agua registrada.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _key() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _add(int amount) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pending ??= (amount: amount, key: _key(), zone: await _zone());
      final pending = _pending!;
      final summary = await _api.add(pending.amount, pending.key, pending.zone);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _pending = null;
      });
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.status != null && e.status! >= 400 && e.status! < 500) {
            _pending = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos confirmar el registro. Reintenta el mismo envío.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _input({required bool goal}) async {
    if (_busy || _dialog || _pending != null) return;
    _dialog = true;
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _WaterInput(goal: goal, initial: goal ? _summary?.goal : 250),
    );
    _dialog = false;
    if (!mounted || amount == null) return;
    if (!goal) {
      await _add(amount);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.goal(amount);
      final summary = await _api.get(await _zone());
      if (mounted) setState(() => _summary = summary);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos confirmar la meta. Actualiza para comprobarla.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _summary;
    final disabled = _busy || _pending != null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: AppTheme.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Agua registrada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Objetivo diario',
                onPressed: disabled ? null : () => _input(goal: true),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (data != null) ...[
            Text(
              '${data.consumed} ml',
              style: const TextStyle(
                fontSize: 24,
                color: AppTheme.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              data.goal == null
                  ? 'Define tu meta diaria'
                  : 'Meta diaria: ${data.goal} ml',
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: data.goal == null
                  ? 0
                  : (data.consumed / data.goal!).clamp(0.0, 1.0),
              color: AppTheme.blue,
            ),
            const SizedBox(height: 8),
            Text(
              'Día: ${data.date}',
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
          if (_error != null || _pending != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error ?? 'Hay un registro pendiente de confirmar.',
                style: const TextStyle(color: Color(0xFF8B251C)),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : _pending == null
                  ? _load
                  : () => _add(_pending!.amount),
              child: Text(
                _pending == null
                    ? 'Actualizar'
                    : 'Reintentar el mismo registro',
              ),
            ),
            if (_pending != null)
              const Text(
                'El reintento conserva el identificador para evitar duplicados. Comprueba el total antes de registrar otra cantidad si sales de esta pantalla.',
                style: TextStyle(fontSize: 12),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: disabled ? null : () => _add(250),
                child: const Text('+ 250 ml'),
              ),
              OutlinedButton(
                onPressed: disabled ? null : () => _add(500),
                child: const Text('+ 500 ml'),
              ),
              TextButton(
                onPressed: disabled ? null : () => _input(goal: false),
                child: const Text('Otra cantidad'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterInput extends StatefulWidget {
  final bool goal;
  final int? initial;
  const _WaterInput({required this.goal, this.initial});
  @override
  State<_WaterInput> createState() => _WaterInputState();
}

class _WaterInputState extends State<_WaterInput> {
  late final TextEditingController _value;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal ? 'Objetivo diario de agua' : 'Añadir agua',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.goal ? 'Meta diaria' : 'Cantidad',
                suffixText: widget.goal ? 'ml / día' : 'ml',
              ),
              validator: (text) {
                final value = int.tryParse(text?.trim() ?? '');
                return value == null || value < 1 || value > 10000
                    ? 'Ingresa un entero entre 1 y 10000 ml.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final value
                    in widget.goal
                        ? [1500, 2000, 2500, 3000]
                        : [150, 250, 500, 750])
                  ActionChip(
                    label: Text('$value ml'),
                    onPressed: () => _value.text = '$value',
                  ),
              ],
            ),
            if (widget.goal)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Cambiar tu meta no modifica el agua ya registrada.',
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, int.parse(_value.text.trim()));
                }
              },
              child: Text(widget.goal ? 'Guardar objetivo' : 'Añadir agua'),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
