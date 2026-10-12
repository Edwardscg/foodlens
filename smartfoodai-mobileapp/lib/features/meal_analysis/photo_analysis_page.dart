import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'detected_food.dart';
import 'photo_analysis_api.dart';

class PhotoAnalysisPage extends ConsumerStatefulWidget {
  const PhotoAnalysisPage({super.key});
  @override
  ConsumerState<PhotoAnalysisPage> createState() => _PhotoAnalysisPageState();
}

class _PhotoAnalysisPageState extends ConsumerState<PhotoAnalysisPage> {
  final _picker = ImagePicker();
  late final PhotoAnalysisApi _api;
  Uint8List? _image;
  List<DetectedFood>? _foods;
  String? _message;
  bool _picking = true;
  CancelToken? _request;
  bool get _busy => _picking || _request != null;

  @override
  void initState() {
    super.initState();
    _api = PhotoAnalysisApi(ref.read(authProvider));
    _checkInterruptedSelection();
  }

  Future<void> _checkInterruptedSelection() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final lost = await _picker.retrieveLostData();
        // A restored file cannot be attributed safely to the current account.
        if (mounted && !lost.isEmpty) {
          _message =
              'La selección anterior se interrumpió. Elige la foto nuevamente.';
        }
      }
    } on PlatformException {
      if (mounted) _message = 'Elige una foto para comenzar.';
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _request?.cancel();
    _api.close();
    _image = null;
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('La foto debe pesar como máximo 5 MB.');
      }
      final bytes = await file.readAsBytes();
      await _validateImage(bytes);
      if (!mounted) return;
      setState(() {
        _image = bytes;
        _foods = null;
      });
    } on PlatformException {
      if (mounted) {
        setState(
          () => _message = 'No pudimos abrir la cámara o galería. Revisa los permisos en Ajustes o usa el registro manual.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'No pudimos leer esa imagen. Elige otra foto.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _validateImage(Uint8List bytes) async {
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 8 &&
        listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    if (bytes.length > 5 * 1024 * 1024 || (!jpeg && !png)) {
      throw const FormatException(
        'Selecciona una imagen JPEG o PNG de hasta 5 MB.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 12000000) {
          throw const FormatException(
            'La imagen es demasiado grande. Elige una foto de hasta 12 megapíxeles.',
          );
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  Future<void> _analyze() async {
    if (_busy || _image == null) return;
    final request = CancelToken();
    setState(() {
      _request = request;
      _message = null;
      _foods = null;
    });
    try {
      final foods = await _api.analyze(_image!, request);
      if (mounted && identical(_request, request)) {
        setState(() => _foods = foods);
      }
    } on ApiFailure catch (error) {
      if (mounted && identical(_request, request)) {
        setState(() => _message = error.message);
      }
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) &&
          mounted &&
          identical(_request, request)) {
        setState(
          () => _message =
              'No pudimos completar el análisis. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted && identical(_request, request)) {
        setState(() => _request = null);
      }
    }
  }

  void _cancel() {
    _request?.cancel();
    setState(() {
      _request = null;
      _message = 'Análisis cancelado. No se ha registrado ninguna comida.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Analizar comida')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _image == null ? 'Añadir una foto' : 'Revisa tu foto',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Centra el plato y usa buena iluminación. La foto se enviará para analizarla solo cuando pulses Analizar.',
              ),
              const SizedBox(height: 20),
              if (_image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _image!,
                    height: 260,
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                    semanticLabel: 'Foto seleccionada para analizar',
                    errorBuilder: (_, _, _) => const Text(
                      'No se puede mostrar la foto. Elige otra imagen.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_message != null) ...[
                Semantics(liveRegion: true, child: Text(_message!)),
                const SizedBox(height: 16),
              ],
              if (_busy) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                Text(
                  _picking ? 'Preparando selección…' : 'Analizando tu foto…',
                  textAlign: TextAlign.center,
                ),
                if (_request != null)
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancelar análisis'),
                  ),
                const SizedBox(height: 16),
              ],
              if (_foods != null) ...[
                Text(
                  _foods!.isEmpty
                      ? 'No identificamos alimentos en esta foto'
                      : 'Alimentos detectados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _foods!.isEmpty
                      ? 'Prueba con otra imagen o registra tu comida manualmente.'
                      : 'Las cantidades son estimaciones. Este análisis todavía no registra la comida ni calcula sus nutrientes.',
                ),
                for (final food in _foods!)
                  Card(
                    child: ListTile(
                      title: Text(food.name),
                      subtitle: Text(
                        food.estimatedGrams == null
                            ? 'Cantidad por revisar'
                            : 'Aproximadamente ${food.estimatedGrams!.toStringAsFixed(1)} g',
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (_image != null && _foods == null)
                FilledButton.icon(
                  onPressed: _busy ? null : _analyze,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Analizar foto'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Tomar foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir de la galería'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final saved = await context.push<bool>('/meals/create');
                        if (context.mounted && saved == true) context.pop(true);
                      },
                child: const Text('Registrar manualmente'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
