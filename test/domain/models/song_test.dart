import 'package:flutter_test/flutter_test.dart';
import 'package:linos/domain/models/song.dart';

void main() {
  group('Song', () {
    test('holds id, title, and artist', () {
      const song = Song(id: '1', title: 'Wonderwall', artist: 'Oasis');
      expect(song.id, '1');
      expect(song.title, 'Wonderwall');
      expect(song.artist, 'Oasis');
    });

    test('equality compares all fields', () {
      const a = Song(id: '1', title: 'Wonderwall', artist: 'Oasis');
      const b = Song(id: '1', title: 'Wonderwall', artist: 'Oasis');
      const c = Song(id: '2', title: 'Wonderwall', artist: 'Oasis');
      const d = Song(id: '1', title: 'Song B', artist: 'Oasis');
      const e = Song(id: '1', title: 'Wonderwall', artist: 'Blur');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a == d, isFalse);
      expect(a == e, isFalse);
    });
  });
}
