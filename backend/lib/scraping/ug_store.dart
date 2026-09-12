import 'dart:convert';

const String _storeMarker = 'class="js-store"';
const String _contentAttr = 'data-content="';

String? extractStoreJson(String html) {
  final markerIndex = html.indexOf(_storeMarker);
  final searchFrom = markerIndex == -1 ? 0 : markerIndex;
  final start = html.indexOf(_contentAttr, searchFrom);
  if (start == -1) return null;
  final valueStart = start + _contentAttr.length;
  final end = html.indexOf('"', valueStart);
  if (end == -1) return null;
  return _decodeEntities(html.substring(valueStart, end));
}

Map<String, dynamic>? decodeStore(String html) {
  final json = extractStoreJson(html);
  if (json == null) return null;
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } catch (_) {
    return null;
  }
}

String _decodeEntities(String value) => value
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');