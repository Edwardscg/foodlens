import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_api.dart';
import 'auth_models.dart';

class RecoveryPage extends StatefulWidget {
  const RecoveryPage({super.key});
  @override
  State<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<RecoveryPage> {
  final _api = AuthApi();
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false, _sent = false, _done = false, _obscure = true;
  String? _error;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _api.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _errors = {};
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (_sent) {
        await _api.resetPassword(_code.text, _password.text);
        if (!mounted) return;
        _code.clear();
        _password.clear();
        _confirmation.clear();
        setState(() => _done = true);
      } else {
        await _api.requestRecovery(_email.text);
        if (!mounted) return;
        setState(() => _sent = true);
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _errors = failure.fields;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No pudimos confirmar la operación. Revisa tu conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        leading: IconButton(
          tooltip: 'Volver a iniciar sesión',
          onPressed: _busy ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _done
                          ? 'Contraseña actualizada'
                          : _sent
                          ? 'Revisa tu correo'
                          : 'Recupera tu acceso',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _done
                          ? 'Tus sesiones anteriores se han cerrado. Inicia sesión con tu nueva contraseña.'
                          : _sent
                          ? 'Si el correo está registrado, recibirás un código. Revisa también spam. Cópialo aquí; caduca en 15 minutos.'
                          : 'Ingresa el correo que usaste para crear tu cuenta.',
                    ),
                    const SizedBox(height: 24),
                    if (!_sent && !_done)
                      TextFormField(
                        key: const ValueKey('email'),
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          errorText: _errors['email'],
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          final email = (value ?? '').trim();
                          return email.length <= 254 &&
                                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)
                              ? null
                              : 'Ingresa un correo válido';
                        },
                      ),
                    if (_sent && !_done) ...[
                      TextFormField(
                        key: const ValueKey('code'),
                        controller: _code,
                        enabled: !_busy,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Código del correo',
                          errorText: _errors['token'],
                          errorMaxLines: 3,
                        ),
                        validator: (value) =>
                            RegExp(r'^[A-Za-z0-9_-]{43}$')
                                .hasMatch((value ?? '').trim())
                            ? null
                            : 'Copia el código completo del correo',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          errorText: _errors['newPassword'],
                          errorMaxLines: 3,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.trim().isEmpty ||
                              password.runes.length < 8) {
                            return 'Usa al menos 8 caracteres';
                          }
                          if (utf8.encode(password).length > 72) {
                            return 'La contraseña es demasiado larga';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value == _password.text
                            ? null
                            : 'Las contraseñas no coinciden',
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!_done)
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(
                          _busy
                              ? 'Procesando…'
                              : _sent
                              ? 'Cambiar contraseña'
                              : 'Enviar código',
                        ),
                      ),
                    if (!_sent && !_done)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _sent = true;
                                _error = null;
                                _errors = {};
                              }),
                        child: const Text('Ya tengo un código'),
                      ),
                    if (_sent && !_done)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _sent = false;
                                _error = null;
                                _errors = {};
                                _code.clear();
                                _password.clear();
                                _confirmation.clear();
                              }),
                        child: const Text('Solicitar otro código'),
                      ),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: const Text('Volver a iniciar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
