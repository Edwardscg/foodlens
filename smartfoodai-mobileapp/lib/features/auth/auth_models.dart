class AuthSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  const AuthSession(this.accessToken, this.refreshToken, this.expiresAt);

  factory AuthSession.fromApi(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final seconds = json['expiresIn'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        seconds is! num ||
        seconds <= 0) {
      throw const FormatException('Invalid session');
    }
    return AuthSession(
      access,
      refresh,
      DateTime.now().toUtc().add(Duration(seconds: seconds.toInt())),
    );
  }
  factory AuthSession.fromStorage(Map<String, dynamic> json) => AuthSession(
    json['accessToken'] as String,
    json['refreshToken'] as String,
    DateTime.parse(json['expiresAt'] as String).toUtc(),
  );
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };
  bool get needsRefresh => !expiresAt.isAfter(
    DateTime.now().toUtc().add(const Duration(seconds: 30)),
  );
}

class AuthUser {
  final int id;
  final String email;
  const AuthUser(this.id, this.email);
  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser((json['id'] as num).toInt(), json['email'] as String);
}

class ApiFailure implements Exception {
  final String message;
  final Map<String, String> fields;
  final int? status;
  const ApiFailure(this.message, {this.fields = const {}, this.status});
}
