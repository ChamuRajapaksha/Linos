import 'dart:convert';

import 'package:linos_backend/api/services.dart';
import 'package:linos_backend/data/song_cache_dao.dart';
import 'package:linos_backend/domain/search_page.dart';
import 'package:linos_backend/scraping/ug_chord_parser.dart';
import 'package:linos_backend/scraping/ug_http_client.dart';
import 'package:linos_backend/scraping/ug_search_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const Map<String, String> jsonHeaders = {'content-type': 'application/json'};

Handler buildHandler({AppServices? services}) {
  final s = services ?? AppServices.real();
  final router = Router()
    ..get('/health', (Request request) => _health(request))
    ..get('/api/search', (Request request) => _search(s, request))
    ..get('/api/songs/<id>', (Request request) => _song(s, request));

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addMiddleware(_jsonErrorMiddleware())
      .addHandler(router.call);
}

Response _health(Request request) => _json(200, {'status': 'ok'});

Future<Response> _search(AppServices s, Request request) async {
  final query = request.url.queryParameters['query']?.trim() ?? '';
  if (query.isEmpty) {
    return _jsonError(400, 'Missing query parameter');
  }
  final pageNum = int.tryParse(request.url.queryParameters['page'] ?? '') ?? 1;
  final requestedPage = pageNum < 1 ? 1 : pageNum;
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 20;
  final requestedLimit = limit < 1 ? 1 : (limit > 50 ? 50 : limit);

  final SearchPage<UgSongResult> page;
  try {
    page = await s.searchClient.search(query, page: requestedPage);
  } on UgConnectionException {
    final cached = await s.songCache.search(query);
    if (cached.isEmpty) {
      return _jsonError(502, 'Upstream search failed');
    }
    return _json(200, {
      'items': cached.map((e) => e.song.toJson()).toList(),
      'page': 1,
      'hasMore': false,
    });
  } on FormatException {
    return _jsonError(502, 'Upstream search returned malformed data');
  }

  await s.songCache.upsert(
    page.items.map((r) => CachedSong(song: r.song, tabUrl: r.tabUrl)),
  );
  final items = page.items.take(requestedLimit).map((r) => r.song.toJson()).toList();
  return _json(200, {
    'items': items,
    'page': page.page,
    'hasMore': page.hasMore,
  });
}

Future<Response> _song(AppServices s, Request request) async {
  final id = request.params['id'] ?? '';
  final cached = await s.chordSheetCache.getById(id);
  if (cached != null) {
    return _json(200, cached.toJson());
  }
  final entry = await s.songCache.getById(id);
  if (entry == null) {
    return _jsonError(404, 'Song not found');
  }
  try {
    final html = await s.ugHttpClient.get(entry.tabUrl);
    final sheet = s.chordParser.parse(html);
    await s.chordSheetCache.upsert(songId: id, sheet: sheet);
    return _json(200, sheet.toJson());
  } on UgConnectionException {
    return _jsonError(502, 'Upstream tab fetch failed');
  } on ChordSheetParseException {
    return _jsonError(502, 'Upstream tab could not be parsed');
  }
}

Middleware _cors() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response(204, headers: corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

Middleware _jsonErrorMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } catch (e, stackTrace) {
        print('Error handling ${request.method} ${request.url}: $e');
        print(stackTrace);
        return Response.internalServerError(
          body: '{"error": "Internal Server Error"}',
          headers: jsonHeaders,
        );
      }
    };
  };
}

Response _json(int status, Map<String, Object?> body) => Response(
      status,
      body: jsonEncode(body),
      headers: jsonHeaders,
    );

Response _jsonError(int status, String message) =>
    _json(status, {'error': message});