import 'dart:io';

import 'package:linos_backend/data/database.dart';
import 'package:linos_backend/scraping/ug_http_client.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeUgHttpClient implements UgHttpClient {
  FakeUgHttpClient(
    Map<String, String> fixtures, {
    this.failAll = false,
  }) : _fixtures = Map.unmodifiable(fixtures);

  final Map<String, String> _fixtures;
  bool failAll;
  final List<String> requestedUrls = <String>[];

  static const String _defaultSearchFixture = 'search_wonderwall_page1.html';
  static const String _defaultTabFixture = 'tab_wonderwall.html';

  @override
  Future<String> get(String url) async {
    requestedUrls.add(url);
    if (failAll) {
      throw UgConnectionException('simulated upstream failure');
    }
    for (final entry in _fixtures.entries) {
      if (url == entry.key || url.contains(entry.key)) {
        return _load(entry.value);
      }
    }
    if (url.contains('search.php')) {
      return _load(_defaultSearchFixture);
    }
    if (url.contains('tabs.ultimate-guitar.com')) {
      return _load(_defaultTabFixture);
    }
    throw StateError('unexpected request: $url');
  }

  String _load(String spec) {
    final path = File('test/fixtures/$spec');
    return path.existsSync() ? path.readAsStringSync() : spec;
  }
}

Database createTestDb() => openInMemoryDatabase();

Uri baseOf(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

String readFixture(String name) => File('test/fixtures/$name').readAsStringSync();