class AppConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const defaultPageSize = 10;
  static const maxPageSize = 100;
}
