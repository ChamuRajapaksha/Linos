import 'package:linos_backend/domain/song.dart';
import 'package:sqlite3/sqlite3.dart';

class CachedSong {
  const CachedSong({required this.song, required this.tabUrl});
  final Song song;
  final String tabUrl;
}

class SongCacheDao {
  SongCacheDao(this._db);
  final Database _db;
  Future<void> upsert(Iterable<CachedSong> songs) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final statement = _db.prepare(
      'INSERT OR REPLACE INTO songs (id, title, artist, tab_url, scraped_at) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    try {
      _db.execute('BEGIN');
      try {
        for (final cached in songs) {
          statement.execute([
            cached.song.id,
            cached.song.title,
            cached.song.artist,
            cached.tabUrl,
            now,
          ]);
        }
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      statement.close();
    }
  }

  Future<CachedSong?> getById(String id) async {
    final statement = _db.prepare('SELECT * FROM songs WHERE id = ?');
    try {
      final rows = statement.select([id]);
      if (rows.isEmpty) return null;
      return _toCached(rows.first);
    } finally {
      statement.close();
    }
  }

  Future<bool> has(String id) async {
    final statement = _db.prepare('SELECT 1 FROM songs WHERE id = ?');
    try {
      return statement.select([id]).isNotEmpty;
    } finally {
      statement.close();
    }
  }

  Future<List<CachedSong>> search(String query) async {
    final pattern = '%${query.toLowerCase()}%';
    final statement = _db.prepare(
      'SELECT * FROM songs WHERE LOWER(title) LIKE ? OR LOWER(artist) LIKE ? '
      'ORDER BY scraped_at DESC LIMIT 50',
    );
    try {
      final rows = statement.select([pattern, pattern]);
      return rows.map(_toCached).whereType<CachedSong>().toList();
    } finally {
      statement.close();
    }
  }

  Future<void> remove(String id) async {
    final statement = _db.prepare('DELETE FROM songs WHERE id = ?');
    try {
      statement.execute([id]);
    } finally {
      statement.close();
    }
  }

  CachedSong? _toCached(Row row) {
    return CachedSong(
      song: Song(
        id: row['id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String,
      ),
      tabUrl: row['tab_url'] as String? ?? '',
    );
  }
}
