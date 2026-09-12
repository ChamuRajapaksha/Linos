import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:linos_backend/api/router.dart';
import 'package:linos_backend/api/services.dart';
import 'package:linos_backend/data/database.dart';
import 'package:linos_backend/data/song_cache_dao.dart';
import 'package:linos_backend/domain/song.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late AppServices services;
  late FakeUgHttpClient fake;
  late http.Client client;

  setUp(() async {
    fake = FakeUgHttpClient(const {});
    services = AppServices(
      database: openInMemoryDatabase(),
      ugHttpClient: fake,
    );
    server = await shelf_io.serve(
      buildHandler(services: services),
      InternetAddress.loopbackIPv4,
      0,
    );
    baseUri = baseOf(server);
    client = http.Client();
  });

  tearDown(() async {
    await server.close(force: true);
    services.close();
    client.close();
  });

  test('GET /health returns status ok', () async {
    final response = await client.get(baseUri.resolve('/health'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('unknown route returns 404', () async {
    final response = await client.get(baseUri.resolve('/nope'));

    expect(response.statusCode, 404);
  });

  test('search without a query returns 400', () async {
    final response = await client.get(baseUri.resolve('/api/search?query='));

    expect(response.statusCode, 400);
    expect(jsonDecode(response.body), {'error': 'Missing query parameter'});
  });

  test('search returns parsed results and calls UG once', () async {
    final response =
        await client.get(baseUri.resolve('/api/search?query=wonderwall'));

    expect(response.statusCode, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['items'], hasLength(3));
    expect(body['items'].first, {
      'id': '6125',
      'title': 'Wonderwall',
      'artist': 'Oasis',
    });
    expect(body['page'], 1);
    expect(body['hasMore'], isTrue);

    final urls = fake.requestedUrls;
    expect(urls, hasLength(1));
    expect(urls.single, contains('type=300'));
    expect(urls.single, contains('value=wonderwall'));
  });

  test('repeated search upserts cached rows without errors', () async {
    final first = await client.get(baseUri.resolve('/api/search?query=wonderwall'));
    final second = await client.get(baseUri.resolve('/api/search?query=wonderwall'));

    expect(first.statusCode, 200);
    expect(second.statusCode, 200);
    final body = jsonDecode(second.body) as Map<String, dynamic>;
    expect(body['items'], hasLength(3));
    expect(fake.requestedUrls, hasLength(2));
  });

  test('search respects the limit parameter', () async {
    final response =
        await client.get(baseUri.resolve('/api/search?query=wonderwall&limit=2'));

    expect(response.statusCode, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['items'], hasLength(2));
    expect(body['hasMore'], isTrue);
    expect(body['page'], 1);
  });

  test('search falls back to the song cache when upstream fails', () async {
    await services.songCache.upsert(const [
      CachedSong(
        song: Song(id: '9', title: 'Wonderwall', artist: 'Oasis'),
        tabUrl: 'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125',
      ),
    ]);
    fake.failAll = true;

    final response =
        await client.get(baseUri.resolve('/api/search?query=wonderwall'));

    expect(response.statusCode, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['items'], [
      {'id': '9', 'title': 'Wonderwall', 'artist': 'Oasis'},
    ]);
    expect(body['hasMore'], isFalse);
    expect(body['page'], 1);
  });

  test('search returns 502 when upstream fails and the cache is empty', () async {
    fake.failAll = true;

    final response =
        await client.get(baseUri.resolve('/api/search?query=wonderwall'));

    expect(response.statusCode, 502);
    expect(jsonDecode(response.body), {'error': 'Upstream search failed'});
  });

  test('song tab is fetched, parsed and served from cache on the second hit',
      () async {
    await services.songCache.upsert(const [
      CachedSong(
        song: Song(id: '6125', title: 'Wonderwall', artist: 'Oasis'),
        tabUrl: 'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125',
      ),
    ]);

    final first = await client.get(baseUri.resolve('/api/songs/6125'));

    expect(first.statusCode, 200);
    final body = jsonDecode(first.body) as Map<String, dynamic>;
    expect(body['title'], 'Wonderwall');
    expect(body['artist'], 'Oasis');
    expect(body['key'], 'F#m');
    final lines = body['lines'] as List;
    expect(lines, isNotEmpty);
    expect(lines.cast<Map<String, dynamic>>().map((l) => l['type']),
        contains('section'));
    expect(fake.requestedUrls, hasLength(1));
    expect(fake.requestedUrls.single, contains('chords-6125'));

    final second = await client.get(baseUri.resolve('/api/songs/6125'));

    expect(second.statusCode, 200);
    expect(fake.requestedUrls, hasLength(1));
  });

  test('unknown song returns 404', () async {
    final response = await client.get(baseUri.resolve('/api/songs/999'));

    expect(response.statusCode, 404);
    expect(jsonDecode(response.body), {'error': 'Song not found'});
  });

  test('known song returns 502 when the upstream tab fetch fails', () async {
    await services.songCache.upsert(const [
      CachedSong(
        song: Song(id: '6125', title: 'Wonderwall', artist: 'Oasis'),
        tabUrl: 'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125',
      ),
    ]);
    fake.failAll = true;

    final response = await client.get(baseUri.resolve('/api/songs/6125'));

    expect(response.statusCode, 502);
    expect(jsonDecode(response.body), {'error': 'Upstream tab fetch failed'});
  });

  test('OPTIONS preflight returns 204 with CORS headers', () async {
    final response = await client.send(
      http.Request('OPTIONS', baseUri.resolve('/api/search')),
    );

    expect(response.statusCode, 204);
    expect(response.headers['access-control-allow-origin'], '*');
  });
}