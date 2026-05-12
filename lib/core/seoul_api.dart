import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class SeoulOpenApi {
  static const String commonKey = '4743524b5863636f38336564544e4c';
  static const String safeRouteKey = '655677566b79736d38377a55436a55';

  final Map<String, LatLng?> _geoCache = {};

  Future<List<Map<String, dynamic>>> fetchAllRows({
    required String service,
    required int limit,
    int pageSize = 1000,
    bool debugPrint = false,
  }) async {
    final key = _resolveKey(service);
    final out = <Map<String, dynamic>>[];
    int start = 1;

    while (start <= limit) {
      final end = (start + pageSize - 1 > limit) ? limit : start + pageSize - 1;
      final uri = Uri.parse(
        'http://openapi.seoul.go.kr:8088/$key/json/$service/$start/$end',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} - $service');
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final root = body[service];
      if (root == null) {
        throw Exception('$service 응답 없음');
      }

      final result = root['RESULT'];
      final code = (result?['CODE'] ?? '').toString();
      final message = (result?['MESSAGE'] ?? '').toString();

      if (code.isNotEmpty && code != 'INFO-000') {
        throw Exception('$service 오류: $code / $message');
      }

      final rows = (root['row'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (rows.isEmpty) break;

      out.addAll(rows);

      if (debugPrint) {
        print('$service : ${rows.length}건 추가, 누적 ${out.length}건');
      }

      if (rows.length < pageSize) break;
      start = end + 1;
    }

    return out;
  }

  String _resolveKey(String service) {
    switch (service) {
      case 'tbSafeReturnItem':
        return safeRouteKey;
      default:
        return commonKey;
    }
  }

  Future<LatLng?> geocodeAddress(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return null;

    if (_geoCache.containsKey(normalized)) {
      return _geoCache[normalized];
    }

    final query = normalized.contains('서울') ? normalized : '서울 $normalized';

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'kr',
      },
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          'User-Agent': 'university/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        _geoCache[normalized] = null;
        return null;
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! List || body.isEmpty) {
        _geoCache[normalized] = null;
        return null;
      }

      final first = body.first;
      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lon = double.tryParse((first['lon'] ?? '').toString());

      if (lat == null || lon == null) {
        _geoCache[normalized] = null;
        return null;
      }

      final result = LatLng(lat, lon);
      _geoCache[normalized] = result;
      return result;
    } catch (_) {
      _geoCache[normalized] = null;
      return null;
    }
  }
}