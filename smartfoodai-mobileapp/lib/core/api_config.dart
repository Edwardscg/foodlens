class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static String get origin => baseUrl.replaceFirst(RegExp(r'/+$'), '');
}
