import 'dart:io';

/// Configuration for the Linos chords backend.
class ApiConfig {
  const ApiConfig({
    this.baseUrl = defaultBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.requestTimeout = const Duration(seconds: 30),
  });

  /// Base URL of the chords backend.
  ///
  /// Defaults to the Android emulator loopback; a deployed proxy can be
  /// selected at build time with
  /// `--dart-define=LINOS_API_URL=https://api.example.com`.
  static const String defaultBaseUrl = String.fromEnvironment(
    'LINOS_API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final String baseUrl;

  /// Timeout for establishing a connection to the backend.
  final Duration connectTimeout;

  /// Timeout for the full request to complete.
  final Duration requestTimeout;

  /// Resolves [path] (which may include a query string) against [baseUrl].
  Uri endpoint(String path) => Uri.parse(baseUrl).resolve(path);

  /// Builds an [HttpClient] honoring [connectTimeout].
  HttpClient buildHttpClient() {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    return client;
  }
}