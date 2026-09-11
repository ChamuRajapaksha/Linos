import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:linos_backend/api/router.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;

  setUp(() async {
    server = await shelf_io.serve(buildHandler(), InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://${server.address.host}:${server.port}');
  });

  tearDown(() => server.close(force: true));

  test('GET /health returns status ok', () async {
    final response = await http.get(baseUri.resolve('/health'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('unknown route returns 404', () async {
    final response = await http.get(baseUri.resolve('/nope'));

    expect(response.statusCode, 404);
  });
}