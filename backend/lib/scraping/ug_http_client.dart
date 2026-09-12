import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract class UgHttpClient {
  Future<String> get(String url);
}

class UgConnectionException implements Exception {
  UgConnectionException(this.message);

  final String message;

  @override
  String toString() => 'UgConnectionException: $message';
}

class HttpUgHttpClient implements UgHttpClient {
  HttpUgHttpClient({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient() {
    _httpClient.userAgent = _userAgent;
    _httpClient.connectionTimeout = _timeout;
  }

  static const String _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0';
  static const Duration _timeout = Duration(seconds: 20);
  static const Duration _rateLimitInterval = Duration(milliseconds: 1000);

  final HttpClient _httpClient;
  DateTime? _lastRequestAt;

  @override
  Future<String> get(String url) async {
    await _respectRateLimit();
    final request =
        await _httpClient.getUrl(Uri.parse(url)).timeout(_timeout);
    final response = await request.close().timeout(_timeout);
    final body =
        await response.transform(utf8.decoder).join().timeout(_timeout);
    if (response.statusCode != 200) {
      throw UgConnectionException(
          'UG request to $url failed with status ${response.statusCode}');
    }
    return body;
  }

  Future<void> _respectRateLimit() async {
    final now = DateTime.now();
    final last = _lastRequestAt;
    if (last != null) {
      final elapsed = now.difference(last);
      if (elapsed < _rateLimitInterval) {
        await Future<void>.delayed(_rateLimitInterval - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();
  }

  void close() {
    _httpClient.close(force: true);
  }
}