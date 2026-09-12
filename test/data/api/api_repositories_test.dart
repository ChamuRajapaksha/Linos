import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/api/api_client.dart';
import 'package:linos/data/api/api_config.dart';
import 'package:linos/data/services/api_chord_sheet_repository.dart';
import 'package:linos/data/services/api_song_search_repository.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';

void main() {
  late HttpServer server;
  late Uri baseUri;
  late ApiClient client;
  late Future<void> Function(HttpRequest request) responder;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      try {
        await responder(request);
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write(e.toString())
          ..close();
      }
    });
    client = ApiClient(config: ApiConfig(baseUrl: baseUri.toString()));
  });

  tearDown(() async {
    await server.close(force: true);
    client.close();
  });

  void respondJson(HttpRequest request, int status, Object body) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }

  group('ApiSongSearchRepository', () {
    test('search returns songs parsed from the backend response', () async {
      responder = (request) async {
        expect(request.uri.path, '/api/search');
        expect(request.uri.queryParameters['query'], 'wonderwall');
        respondJson(request, 200, {
          'items': [
            {'id': '6125', 'title': 'Wonderwall', 'artist': 'Oasis'},
          ],
          'page': 1,
          'hasMore': false,
        });
      };

      final repo = ApiSongSearchRepository(apiClient: client);
      final songs = await repo.search('wonderwall');

      expect(songs, const [Song(id: '6125', title: 'Wonderwall', artist: 'Oasis')]);
    });

    test('5xx response surfaces as ApiException with the backend message',
        () async {
      responder = (request) async {
        respondJson(request, 502, {'error': 'Upstream search failed'});
      };

      final repo = ApiSongSearchRepository(apiClient: client);

      await expectLater(
        repo.search('wonderwall'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.message,
                'message',
                'Upstream search failed',
              ),
        ),
      );
    });

    test('malformed response body throws ApiException', () async {
      responder = (request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('not json at all')
          ..close();
      };

      final repo = ApiSongSearchRepository(apiClient: client);

      await expectLater(
        repo.search('wonderwall'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Malformed response'),
          ),
        ),
      );
    });

    test('request timeout throws ApiException', () async {
      final slowClient = ApiClient(
        config: ApiConfig(
          baseUrl: baseUri.toString(),
          requestTimeout: const Duration(milliseconds: 50),
        ),
      );
      responder = (request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        request.response.close();
      };

      final repo = ApiSongSearchRepository(apiClient: slowClient);

      await expectLater(
        repo.search('wonderwall'),
        throwsA(isA<ApiException>()),
      );
      slowClient.close();
    });

    test('network failure surfaces as ApiException', () async {
      final unreachable = ApiClient(
        config: ApiConfig(baseUrl: 'http://127.0.0.1:1'),
      );
      final repo = ApiSongSearchRepository(apiClient: unreachable);

      await expectLater(
        repo.search('wonderwall'),
        throwsA(isA<ApiException>()),
      );
      unreachable.close();
    });
  });

  group('ApiChordSheetRepository', () {
    const song = Song(id: '6125', title: 'Wonderwall', artist: 'Oasis');

    test('fetch parses a sheet from the backend response', () async {
      responder = (request) async {
        expect(request.uri.path, '/api/songs/6125');
        respondJson(request, 200, {
          'title': 'Wonderwall',
          'artist': 'Oasis',
          'key': 'F#m',
          'lines': [
            {'type': 'section', 'name': '[Verse 1]'},
            {
              'type': 'lyric',
              'words': [
                {'word': 'Today', 'chord': 'F#m'},
              ],
            },
          ],
        });
      };

      final repo = ApiChordSheetRepository(apiClient: client);
      final sheet = await repo.fetch(song);

      expect(sheet.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
      expect(sheet.key, 'F#m');
      expect(sheet.lines, hasLength(2));
      expect(sheet.lines.first, isA<SongSection>());
      final lyric = sheet.lines.last as LyricLine;
      expect(lyric.words.single.chord, 'F#m');
    });

    test('404 surfaces as ApiException with the backend message', () async {
      responder = (request) async {
        respondJson(request, 404, {'error': 'Song not found'});
      };

      final repo = ApiChordSheetRepository(apiClient: client);

      await expectLater(
        repo.fetch(song),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Song not found'),
        ),
      );
    });
  });
}