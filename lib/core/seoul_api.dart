import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Thrown when the app was started without an API key.
class MissingApiKeyException implements Exception {
  @override
  String toString() =>
      '서울시 Open API 인증키가 없습니다. README의 "실행" 절을 참고해 '
      '--dart-define-from-file=dart_defines.json 으로 실행하세요.';
}

class SeoulOpenApi {
  /// Passed at build time: `--dart-define-from-file=dart_defines.json`.
  static const String keyFromEnvironment = String.fromEnvironment('SEOUL_API_KEY');

  /// The Seoul Open API only answers over plain HTTP on port 8088.
  static const String baseUrl = 'http://openapi.seoul.go.kr:8088';

  /// Nominatim's usage policy: at most one request per second and an
  /// identifying User-Agent.
  static const Duration geocodeInterval = Duration(milliseconds: 1100);
  static const String userAgent =
      'seoul-safety-map/1.0 (+https://github.com/cynkai/seoul-safety-map)';

  final String apiKey;
  final http.Client _client;
  final Map<String, LatLng?> _geoCache = {};
  DateTime? _lastGeocodeAt;

  SeoulOpenApi({String apiKey = keyFromEnvironment, http.Client? client})
      : apiKey = apiKey.trim(),
        _client = client ?? http.Client();

  /// Fetches every row of [service], or only the first [limit] rows,
  /// [pageSize] at a time (the API returns at most 1,000 per request).
  Future<List<Map<String, dynamic>>> fetchAllRows({
    required String service,
    int? limit,
    int pageSize = 1000,
  }) async {
    if (apiKey.isEmpty) throw MissingApiKeyException();

    final out = <Map<String, dynamic>>[];
    var start = 1;
    var last = limit; // last row to fetch; narrowed by list_total_count

    while (last == null || start <= last) {
      final end = last == null ? start + pageSize - 1 : math.min(start + pageSize - 1, last);
      final uri = Uri.parse('$baseUrl/$apiKey/json/$service/$start/$end');

      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} - $service');
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final root = body is Map ? body[service] : null;
      if (root == null) {
        // Errors such as an invalid key come back as a top-level RESULT.
        final result = body is Map ? body['RESULT'] : null;
        final code = (result?['CODE'] ?? '').toString();
        final message = (result?['MESSAGE'] ?? '').toString();
        throw Exception(code.isEmpty ? '$service 응답 없음' : '$service 오류: $code / $message');
      }

      final result = root['RESULT'];
      final code = (result?['CODE'] ?? '').toString();
      final message = (result?['MESSAGE'] ?? '').toString();
      if (code.isNotEmpty && code != 'INFO-000') {
        throw Exception('$service 오류: $code / $message');
      }

      final total = int.tryParse((root['list_total_count'] ?? '').toString());
      if (total != null) last = last == null ? total : math.min(last, total);

      final rows = (root['row'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (rows.isEmpty) break;
      out.addAll(rows);
      if (rows.length < end - start + 1) break;
      start = end + 1;
    }

    return out;
  }

  /// Looks up an address with OpenStreetMap Nominatim. Only used for rows
  /// that come without coordinates; requests are spaced per the usage policy
  /// and cached.
  Future<LatLng?> geocodeAddress(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return null;
    if (_geoCache.containsKey(normalized)) return _geoCache[normalized];

    final previous = _lastGeocodeAt;
    if (previous != null) {
      final wait = geocodeInterval - DateTime.now().difference(previous);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    _lastGeocodeAt = DateTime.now();

    final query = normalized.contains('서울') ? normalized : '서울 $normalized';
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'kr',
    });

    LatLng? result;
    try {
      final res = await _client.get(uri, headers: {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is List && body.isNotEmpty) {
          final lat = double.tryParse((body.first['lat'] ?? '').toString());
          final lon = double.tryParse((body.first['lon'] ?? '').toString());
          if (lat != null && lon != null) result = LatLng(lat, lon);
        }
      }
    } catch (_) {
      result = null;
    }

    _geoCache[normalized] = result;
    return result;
  }
}
