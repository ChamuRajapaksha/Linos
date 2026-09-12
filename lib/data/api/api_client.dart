import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_config.dart';

/// Typed error raised for every failure mode of [ApiClient]: network errors,
/// timeouts, non-2xx HTTP statuses and malformed payloads.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : 'HTTP $statusCode: $message';
}

/// Thin HTTP wrapper around the Linos chords backend.
///
/// Every GET returns decoded JSON (a `Map<String, dynamic>`) and every
/// failure surfaces as an [ApiException], so callers never see raw
/// transport errors.
class ApiClient {
  ApiClient({ApiConfig config = const ApiConfig(), http.Client? httpClient})
      : _config = config,
        _http = httpClient ?? IOClient(config.buildHttpClient());

  final ApiConfig _config;
  final http.Client _http;

  /// Fetches [path] and decodes the JSON response body.
  ///
  /// [query] entries are merged over any query already present on [path].
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _endpoint(path, query);
    final http.Response response;
    try {
      response = await _http.get(uri).timeout(_config.requestTimeout);
    } on TimeoutException {
      throw ApiException('Request to $path timed out');
    } on http.ClientException catch (e) {
      throw ApiException('Network error requesting $path: ${e.message}');
    } on SocketException catch (e) {
      throw ApiException('Network error requesting $path: ${e.message}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(response) ?? 'Request to $path failed',
        statusCode: response.statusCode,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Malformed response from $path');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Malformed response from $path: expected a JSON object',
      );
    }
    return decoded;
  }

  void close() {
    _http.close();
  }

  Uri _endpoint(String path, Map<String, String>? query) {
    final uri = _config.endpoint(path);
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  String? _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return null;
  }
}