import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session_store.dart';
import 'auth_api.dart';
import 'auth_models.dart';

enum AuthStatus { restoring, signedOut, signedIn, offline }

final authProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController(AuthApi(), SessionStore());
  unawaited(controller.restore());
  return controller;
});

class AuthController extends ChangeNotifier {
  final AuthApi _api;
  final SessionStore _store;
  AuthController(this._api, this._store);
  AuthStatus status = AuthStatus.restoring;
  AuthUser? user;
  AuthSession? _session;
  bool busy = false;
  String? message;
  String? notice;
  Map<String, String> fieldErrors = {};
  Future<void>? _refreshing;
  bool _flushing = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    status = AuthStatus.restoring;
    message = null;
    _notify();
    try {
      _session = await _store.readSession();
      if (_session == null) {
        user = null;
        status = AuthStatus.signedOut;
      } else {
        user = await _identity();
        status = AuthStatus.signedIn;
      }
    } on ApiFailure catch (error) {
      if (error.status == 401) {
        await _discardSession();
      } else {
        status = AuthStatus.offline;
        message = error.message;
      }
    } catch (_) {
      status = AuthStatus.offline;
      message = 'No pudimos recuperar tu sesión en este dispositivo.';
    } finally {
      busy = false;
      _notify();
      unawaited(_flushRevocations());
    }
  }

  Future<AuthUser> _identity() async {
    final alreadyRefreshed = _session!.needsRefresh;
    if (alreadyRefreshed) await _rotate();
    try {
      return await _api.me(_session!.accessToken);
    } on ApiFailure catch (error) {
      if (error.status != 401 || alreadyRefreshed) rethrow;
      await _rotate();
      return _api.me(_session!.accessToken);
    }
  }

  Future<void> _rotate() async {
    if (_refreshing != null) return _refreshing!;
    final operation = _rotateOnce();
    _refreshing = operation;
    try {
      await operation;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _rotateOnce() async {
    final previous = _session;
    if (previous == null)
      throw const ApiFailure('Inicia sesión nuevamente.', status: 401);
    final next = await _api.refresh(previous.refreshToken);
    if (!identical(_session, previous) || _disposed) {
      throw const ApiFailure('La sesión cambió.', status: 401);
    }
    await _store.save(next);
    if (!identical(_session, previous) || _disposed) {
      throw const ApiFailure('La sesión cambió.', status: 401);
    }
    _session = next;
  }

  // Renew access before a request. Only reads may retry after a rejected token.
  Future<T> withAccessToken<T>(
      Future<T> Function(String token) operation, {
        bool retryUnauthorized = false,
      }) async {
    final owner = user?.id;
    void checkSession() {
      if (_disposed ||
          status != AuthStatus.signedIn ||
          owner == null ||
          user?.id != owner ||
          _session == null) {
        throw const ApiFailure('Inicia sesión nuevamente.', status: 401);
      }
    }

    checkSession();
    try {
      final refreshed = _session!.needsRefresh;
      if (refreshed) await _rotate();
      checkSession();
      T result;
      try {
        result = await operation(_session!.accessToken);
      } on ApiFailure catch (error) {
        if (error.status != 401 || refreshed) rethrow;
        checkSession();
        await _rotate();
        checkSession();
        if (!retryUnauthorized) {
          throw const ApiFailure(
            'Tu sesión se renovó. Vuelve a guardar el alimento.',
          );
        }
        result = await operation(_session!.accessToken);
      }
      checkSession();
      return result;
    } on ApiFailure catch (error) {
      if (!_disposed &&
          error.status == 401 &&
          user?.id == owner &&
          status == AuthStatus.signedIn) {
        await _discardSession();
        _notify();
      }
      rethrow;
    }
  }

  Future<void> _discardSession() async {
    try {
      await _store.signOut(_session?.refreshToken);
      _session = null;
      user = null;
      status = AuthStatus.signedOut;
      notice = 'Tu sesión terminó. Inicia sesión nuevamente.';
    } catch (_) {
      status = AuthStatus.offline;
      message = 'No pudimos actualizar la sesión guardada. Inténtalo de nuevo.';
    }
  }

  Future<void> submit(
      String email,
      String password, {
        required bool register,
      }) async {
    if (busy) return;
    busy = true;
    message = null;
    notice = null;
    fieldErrors = {};
    _notify();
    try {
      _session = await _api.signIn(email, password, register: register);
      await _store.save(_session!);
      user = await _identity();
      status = AuthStatus.signedIn;
      if (register) notice = 'Cuenta creada. La configuración de perfil estará disponible en la siguiente entrega.';
    } on ApiFailure catch (error) {
      message = error.message;
      fieldErrors = error.fields;
      if (_session != null) status = AuthStatus.offline;
    } catch (_) {
      message = 'No pudimos guardar tu sesión en este dispositivo. Inténtalo nuevamente.';
      if (_session != null) status = AuthStatus.offline;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await _store.signOut(_session?.refreshToken);
      _session = null;
      user = null;
      status = AuthStatus.signedOut;
      message = null;
      fieldErrors = {};
      notice = 'Sesión cerrada en este dispositivo. Confirmaremos el cierre al conectar.';
      unawaited(_flushRevocations());
    } catch (_) {
      message = 'No pudimos cerrar la sesión guardada. Inténtalo nuevamente.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _flushRevocations() async {
    if (_flushing) return;
    _flushing = true;
    try {
      for (final token in await _store.pending()) {
        try {
          await _api.logout(token);
          await _store.acknowledge(token);
        } catch (_) {
          break;
        }
      }
    } catch (_) {
      // The encrypted queue remains available for the next attempt.
    } finally {
      _flushing = false;
    }
  }

  void clearErrors() {
    if (busy) return;
    message = null;
    fieldErrors = {};
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _api.dispose();
    super.dispose();
  }
}
