import 'package:linos_backend/data/chord_sheet_cache_dao.dart';
import 'package:linos_backend/data/database.dart';
import 'package:linos_backend/data/song_cache_dao.dart';
import 'package:linos_backend/scraping/ug_chord_parser.dart';
import 'package:linos_backend/scraping/ug_http_client.dart';
import 'package:linos_backend/scraping/ug_search_client.dart';
import 'package:sqlite3/sqlite3.dart';

class AppServices {
  AppServices({required Database database, required UgHttpClient ugHttpClient})
      : songCache = SongCacheDao(database),
        chordSheetCache = ChordSheetCacheDao(database),
        searchClient = UgSearchClient(ugHttpClient),
        chordParser = const UgChordParser(),
        ugHttpClient = ugHttpClient,
        _database = database,
        _httpClient = ugHttpClient;

  factory AppServices.real({String dbPath = 'linos.db'}) => AppServices(
        database: openDatabase(path: dbPath),
        ugHttpClient: HttpUgHttpClient(),
      );

  final SongCacheDao songCache;
  final ChordSheetCacheDao chordSheetCache;
  final UgSearchClient searchClient;
  final UgChordParser chordParser;
  final UgHttpClient ugHttpClient;
  final Database _database;
  final UgHttpClient _httpClient;

  void close() {
    if (_httpClient case final HttpUgHttpClient client) {
      client.close();
    }
    _database.close();
  }
}