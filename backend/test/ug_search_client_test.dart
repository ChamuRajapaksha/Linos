import 'package:linos_backend/scraping/ug_search_client.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late FakeUgHttpClient fake;
  late UgSearchClient client;

  setUp(() {
    fake = FakeUgHttpClient(const {});
    client = UgSearchClient(fake);
  });

  test('page 1 parses rows, ids, tab urls and pagination', () async {
    final page = await client.search('wonderwall');

    expect(page.page, 1);
    expect(page.hasMore, isTrue);
    expect(page.items, hasLength(3));
    final result = page.items.first;
    expect(result.song.id, '6125');
    expect(result.song.title, 'Wonderwall');
    expect(result.song.artist, 'Oasis');
    expect(result.tabUrl,
        'https://tabs.ultimate-guitar.com/tab/oasis/wonderwall-chords-6125');
    expect(fake.requestedUrls.single, contains('type=300&value=wonderwall'));
  });

  test('page 2 parses rows and echoes the requested page', () async {
    final fake2 = FakeUgHttpClient({
      'page=2': 'search_wonderwall_page2.html',
    });
    final page = await UgSearchClient(fake2).search('wonderwall', page: 2);

    expect(page.page, 2);
    expect(page.items, hasLength(2));
    expect(page.items.map((r) => r.song.id), ['7001', '7002']);
    expect(page.hasMore, isTrue);
  });

  test('single-page store reports no more pages', () async {
    const html = '<div class="js-store" data-content="'
        '{&quot;store&quot;:{&quot;page&quot;:{&quot;data&quot;:{&quot;results&quot;:['
        '{&quot;id&quot;:1,&quot;song_name&quot;:&quot;Only One&quot;,'
        '&quot;artist_name&quot;:&quot;Artist&quot;,'
        '&quot;tab_url&quot;:&quot;https://tabs.ultimate-guitar.com/tab/a/only-one-chords-1&quot;}],'
        '&quot;pagination&quot;:{&quot;total&quot;:1,&quot;current&quot;:1}}}}}"></div>';
    final fake2 = FakeUgHttpClient({'search.php': html});

    final page = await UgSearchClient(fake2).search('only');

    expect(page.page, 1);
    expect(page.hasMore, isFalse);
    expect(page.items, hasLength(1));
  });

  test('store without a results key returns an empty page', () async {
    const html = '<div class="js-store" data-content="'
        '{&quot;store&quot;:{&quot;page&quot;:{&quot;data&quot;:{&quot;foo&quot;:1}}}}"></div>';
    final fake2 = FakeUgHttpClient({'search.php': html});

    final page = await UgSearchClient(fake2).search('x', page: 3);

    expect(page.items, isEmpty);
    expect(page.page, 3);
    expect(page.hasMore, isFalse);
  });

  test('html without a js-store throws FormatException', () async {
    final fake2 = FakeUgHttpClient({'search.php': '<html><body></body></html>'});

    await expectLater(
      UgSearchClient(fake2).search('x'),
      throwsA(isA<FormatException>()),
    );
  });

  test('malformed store json throws FormatException', () async {
    const html =
        '<div class="js-store" data-content="{&quot;store&quot;:{&quot;a&quot;:}"></div>';
    final fake2 = FakeUgHttpClient({'search.php': html});

    await expectLater(
      UgSearchClient(fake2).search('x'),
      throwsA(isA<FormatException>()),
    );
  });
}