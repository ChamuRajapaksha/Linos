import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:linos/data/api/api_models.dart';
import 'package:linos/domain/models/chord_sheet.dart';
import 'package:linos/domain/models/song.dart';

void main() {
  group('SearchResponse.fromJson', () {
    test('parses items, page and hasMore', () {
      final json = jsonDecode('''
        {
          "items": [
            {"id": "6125", "title": "Wonderwall", "artist": "Oasis"},
            {"id": "944", "title": "Creep", "artist": "Radiohead"}
          ],
          "page": 2,
          "hasMore": true
        }
      ''') as Map<String, dynamic>;

      final response = SearchResponse.fromJson(json);

      expect(response.items, const [
        Song(id: '6125', title: 'Wonderwall', artist: 'Oasis'),
        Song(id: '944', title: 'Creep', artist: 'Radiohead'),
      ]);
      expect(response.page, 2);
      expect(response.hasMore, isTrue);
    });

    test('parses an empty result page', () {
      final json = jsonDecode('''
        {"items": [], "page": 1, "hasMore": false}
      ''') as Map<String, dynamic>;

      final response = SearchResponse.fromJson(json);

      expect(response.items, isEmpty);
      expect(response.page, 1);
      expect(response.hasMore, isFalse);
    });
  });

  group('ChordSheetDto.fromJson', () {
    test('parses section and lyric lines into the domain model', () {
      final json = jsonDecode('''
        {
          "title": "Wonderwall",
          "artist": "Oasis",
          "key": "F#m",
          "lines": [
            {"type": "section", "name": "[Verse 1]"},
            {
              "type": "lyric",
              "words": [
                {"word": "Today", "chord": "F#m"},
                {"word": "is"},
                {"word": "gonna", "chord": "A"}
              ]
            }
          ]
        }
      ''') as Map<String, dynamic>;

      final sheet = ChordSheetDto.fromJson(json).toDomain();

      expect(sheet.title, 'Wonderwall');
      expect(sheet.artist, 'Oasis');
      expect(sheet.key, 'F#m');
      expect(sheet.lines, hasLength(2));
      expect(sheet.lines.first, isA<SongSection>());
      expect((sheet.lines.first as SongSection).name, '[Verse 1]');

      final lyric = sheet.lines[1] as LyricLine;
      expect(lyric.words, hasLength(3));
      expect(lyric.words[0].word, 'Today');
      expect(lyric.words[0].chord, 'F#m');
      expect(lyric.words[1].chord, isNull);
      expect(lyric.words[2].word, 'gonna');
    });

    test('omits key when absent', () {
      final json = jsonDecode('''
        {
          "title": "Creep",
          "artist": "Radiohead",
          "lines": []
        }
      ''') as Map<String, dynamic>;

      final sheet = ChordSheetDto.fromJson(json).toDomain();

      expect(sheet.title, 'Creep');
      expect(sheet.key, isNull);
      expect(sheet.lines, isEmpty);
    });

    test('throws FormatException on an unknown line type', () {
      final json = jsonDecode('''
        {
          "title": "Creep",
          "artist": "Radiohead",
          "lines": [
            {"type": "tab", "content": "e|-0-"}
          ]
        }
      ''') as Map<String, dynamic>;

      expect(
        () => ChordSheetDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}