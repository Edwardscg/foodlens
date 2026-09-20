import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/auth_models.dart';
import 'api_config.dart';

class SessionStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _key = 'smartfood.session.${Uri.encodeComponent(ApiConfig.origin)}';
  Future<void> _tail = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final job = _tail.then((_) => action());
    _tail = job.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return job;
  }

  Future<Map<String, dynamic>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) =>
      _storage.write(key: _key, value: jsonEncode(data));

  Future<AuthSession?> readSession() => _locked(() async {
    final data = await _read();
    if (data['session'] is! Map) return null;
    try {
      return AuthSession.fromStorage(
        Map<String, dynamic>.from(data['session'] as Map),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  });
  Future<void> save(AuthSession session) => _locked(() async {
    final data = await _read();
    data['session'] = session.toJson();
    await _write(data);
  });
  Future<void> signOut(String? token) => _locked(() async {
    final data = await _read();
    final pending = (data['pending'] as List? ?? [])
        .whereType<String>()
        .toSet();
    if (token != null) pending.add(token);
    data.remove('session');
    data['pending'] = pending.toList();
    await _write(data);
  });
  Future<List<String>> pending() => _locked(() async {
    final data = await _read();
    return (data['pending'] as List? ?? []).whereType<String>().toList();
  });
  Future<void> acknowledge(String token) => _locked(() async {
    final data = await _read();
    data['pending'] = (data['pending'] as List? ?? [])
        .whereType<String>()
        .where((value) => value != token)
        .toList();
    await _write(data);
  });
}
