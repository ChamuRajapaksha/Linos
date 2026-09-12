import 'dart:convert';
import 'package:linos_backend/domain/chord_sheet.dart';
import 'package:sqlite3/sqlite3.dart';

class ChordSheetCacheDao {
  ChordSheetCacheDao(this._db);
  final Database _db;
  Future<void> upsert({
    required String songId,
    required ChordSheet sheet,
  }) async {
    final statement = _db.prepare(
      'INSERT OR REPLACE INTO chord_sheets '
      '(song_id, title, artist, key, lines_json, scraped_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
    );
    try {
      statement.execute([
        songId,
        sheet.title,
        sheet.artist,
        sheet.key,
        jsonEncode(songLinesToJson(sheet.lines)),
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ]);
    } finally {
      statement.close();
    }
  }

  Future<ChordSheet?> getById(String id) async {
    final statement = _db.prepare(
      'SELECT * FROM chord_sheets WHERE song_id = ?',
    );
    try {
      final rows = statement.select([id]);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final linesJson = jsonDecode(row['lines_json'] as String) as List;
      return ChordSheet(
        title: row['title'] as String,
        artist: row['artist'] as String,
        key: row['key'] as String?,
        lines: songLinesFromJson(linesJson.cast<Map<String, dynamic>>()),
      );
    } finally {
      statement.close();
    }
  }

  Future<bool> has(String id) async {
    final statement = _db.prepare(
      'SELECT 1 FROM chord_sheets WHERE song_id = ?',
    );
    try {
      return statement.select([id]).isNotEmpty;
    } finally {
      statement.close();
    }
  }
}
