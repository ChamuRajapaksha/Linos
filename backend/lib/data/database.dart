import 'package:sqlite3/sqlite3.dart';

const _songsTableDdl = 'CREATE TABLE IF NOT EXISTS songs ('
    'id TEXT PRIMARY KEY NOT NULL, '
    'title TEXT NOT NULL, '
    'artist TEXT NOT NULL, '
    'tab_url TEXT NOT NULL, '
    'scraped_at INTEGER NOT NULL'
    ');'
    'CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title);';

const _chordSheetsTableDdl = 'CREATE TABLE IF NOT EXISTS chord_sheets ('
    'song_id TEXT PRIMARY KEY NOT NULL REFERENCES songs(id) ON DELETE CASCADE, '
    'title TEXT NOT NULL, '
    'artist TEXT NOT NULL, '
    'key TEXT, '
    'lines_json TEXT NOT NULL, '
    'scraped_at INTEGER NOT NULL'
    ');';

const _allDdl = 'BEGIN;${_songsTableDdl}${_chordSheetsTableDdl}COMMIT;';

void _migrate(Database db) {
  db.execute(_allDdl);
}

Database openDatabase({String path = 'linos.db'}) {
  final db = sqlite3.open(path);
  _migrate(db);
  return db;
}

Database openInMemoryDatabase() {
  final db = sqlite3.openInMemory();
  _migrate(db);
  return db;
}
