import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import 'auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  final bool register;
  const AuthPage({super.key, this.register = false});
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    ref.read(authProvider).clearErrors();
    if (!_form.currentState!.validate()) return;
    await ref
        .read(authProvider)
        .submit(_email.text, _password.text, register: widget.register);
    if (!mounted) return;
    if (ref.read(authProvider).status == AuthStatus.signedIn) {
      TextInput.finishAutofillContext();
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final register = widget.register;
    return PopScope(
      canPop: !auth.busy,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, register ? 24 : 104, 24, 32),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (register) ...[
                          IconButton(
                            onPressed: auth.busy
                                ? null
                                : () {
                              auth.clearErrors();
                              context.go('/login');
                            },
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            tooltip: 'Volver a iniciar sesión',
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          register ? 'Crea tu cuenta' : 'Inicia sesión',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          register
                              ? 'Guarda tu registro de comidas en un solo lugar'
                              : 'Continúa con tu registro de comidas',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        if (auth.notice != null && !register) ...[
                          _Message(auth.notice!),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Correo electrónico',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _email,
                          enabled: !auth.busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: 'nombre@ejemplo.com',
                            errorText: auth.fieldErrors['email'],
                            errorMaxLines: 3,
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty)
                              return 'Ingresa tu correo electrónico';
                            if (email.length > 254 ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(email)) {
                              return 'Ingresa un correo válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Contraseña',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _password,
                          enabled: !auth.busy,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!auth.busy) _submit();
                          },
                          decoration: InputDecoration(
                            hintText: register
                                ? 'Crea tu contraseña'
                                : 'Introduce tu contraseña',
                            errorText: auth.fieldErrors['password'],
                            errorMaxLines: 3,
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: auth.busy
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.trim().isEmpty)
                              return 'Ingresa tu contraseña';
                            if (register && password.runes.length < 8)
                              return 'Usa al menos 8 caracteres';
                            if (utf8.encode(password).length > 72)
                              return 'La contraseña es demasiado larga';
                            return null;
                          },
                        ),
                        if (register) ...[
                          const SizedBox(height: 10),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info, color: AppTheme.blue, size: 15),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Usa una contraseña de al menos 8 caracteres.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (auth.message != null) ...[
                          const SizedBox(height: 20),
                          _Message(auth.message!, error: true),
                        ],
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: auth.busy ? null : _submit,
                          child: auth.busy
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            register ? 'Crear cuenta' : 'Iniciar sesión',
                          ),
                        ),
                        if (!register)
                          Center(
                            child: TextButton(
                              onPressed: auth.busy
                                  ? null
                                  : () {
                                auth.clearErrors();
                                context.push('/register');
                              },
                              child: const Text(
                                '¿No tienes cuenta? Crear cuenta',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;
  const _Message(this.text, {this.error = false});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEDEA) : const Color(0xFFE7F0E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? const Color(0xFF8B251C) : AppTheme.green,
        ),
      ),
    ),
  );
}
