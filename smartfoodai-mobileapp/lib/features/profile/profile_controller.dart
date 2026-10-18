import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'profile_api.dart';
import 'profile_models.dart';

final profileProvider = ChangeNotifierProvider<ProfileController>(
  (ref) => ProfileController(ref.read(authProvider), ProfileApi()),
);

class ProfileController extends ChangeNotifier {
  final AuthController _auth;
  final ProfileApi _api;
  UserProfile? profile;
  String? error;
  bool loading = false;
  int? _owner;
  int _revision = 0;
  bool _disposed = false;
  ProfileController(this._auth, this._api) {
    _auth.addListener(_authChanged);
    scheduleMicrotask(_authChanged);
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    if (_disposed) return;
    if (_auth.status == AuthStatus.signedOut) {
      _revision++;
      _owner = null;
      profile = null;
      error = null;
      loading = false;
      _notify();
    } else if (_auth.status == AuthStatus.signedIn &&
        _auth.user?.id != _owner) {
      _revision++;
      _owner = _auth.user?.id;
      profile = null;
      loading = false;
      error = null;
      unawaited(load());
    }
  }

  Future<void> load() async {
    if (_disposed ||
        loading ||
        _owner == null ||
        _auth.status != AuthStatus.signedIn) {
      return;
    }
    final revision = ++_revision;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await _auth.withAccessToken(
        _api.get,
        retryUnauthorized: true,
      );
      if (!_disposed && revision == _revision) profile = result;
    } on ApiFailure catch (failure) {
      if (!_disposed && revision == _revision) error = failure.message;
    } catch (_) {
      if (!_disposed && revision == _revision) {
        error = 'No pudimos recuperar tu perfil.';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  Future<CalorieSuggestion> suggest(ProfileData data) => _auth.withAccessToken(
    (token) => _api.suggest(token, data),
    retryUnauthorized: true,
  );

  Future<void> save(
    ProfileData data, {
    required bool suggested,
    int? target,
  }) async {
    final revision = _revision;
    final result = await _auth.withAccessToken(
      (token) => _api.save(token, data, suggested: suggested, target: target),
    );
    if (_disposed || revision != _revision) {
      throw const ApiFailure('La sesión cambió. Inténtalo nuevamente.');
    }
    profile = result;
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _auth.removeListener(_authChanged);
    _api.dispose();
    super.dispose();
  }
}
