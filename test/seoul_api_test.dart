import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seoul_safety_map/core/seoul_api.dart';

http.Response page(String service, int total, int from, int to) {
  final rows = [for (var i = from; i <= to && i <= total; i++) {'ID': '$i'}];
  return http.Response(
    jsonEncode({
      service: {
        'list_total_count': total,
        'RESULT': {'CODE': 'INFO-000', 'MESSAGE': '정상 처리되었습니다'},
        'row': rows,
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('fetches every page up to list_total_count', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      final parts = request.url.pathSegments; // key/json/service/start/end
      requested.add('${parts[3]}-${parts[4]}');
      return page(parts[2], 2345, int.parse(parts[3]), int.parse(parts[4]));
    });
    final api = SeoulOpenApi(apiKey: 'test-key', client: client);

    final rows = await api.fetchAllRows(service: 'mgisToiletPoi');

    expect(rows, hasLength(2345));
    expect(requested, ['1-1000', '1001-2000', '2001-2345']);
  });

  test('stops at an explicit limit', () async {
    final client = MockClient((request) async {
      final parts = request.url.pathSegments;
      return page(parts[2], 5000, int.parse(parts[3]), int.parse(parts[4]));
    });
    final api = SeoulOpenApi(apiKey: 'test-key', client: client);

    expect(await api.fetchAllRows(service: 'x', limit: 1500), hasLength(1500));
  });

  test('puts the key in the path and never in a hard-coded constant', () async {
    late Uri seen;
    final api = SeoulOpenApi(
      apiKey: ' my-key ',
      client: MockClient((request) async {
        seen = request.url;
        return page('svc', 1, 1, 1);
      }),
    );
    await api.fetchAllRows(service: 'svc');
    expect(seen.toString(), 'http://openapi.seoul.go.kr:8088/my-key/json/svc/1/1000');
  });

  test('throws a clear error without a key', () async {
    final api = SeoulOpenApi(apiKey: '', client: MockClient((_) async => fail('no request')));
    expect(() => api.fetchAllRows(service: 'svc'), throwsA(isA<MissingApiKeyException>()));
  });

  test('surfaces API error codes, including top-level ones for a bad key', () async {
    final api = SeoulOpenApi(
      apiKey: 'bad',
      client: MockClient((_) async => http.Response(
            jsonEncode({'RESULT': {'CODE': 'INFO-100', 'MESSAGE': '인증키가 유효하지 않습니다.'}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    expect(
      () => api.fetchAllRows(service: 'svc'),
      throwsA(predicate((e) => e.toString().contains('INFO-100'))),
    );
  });

  test('geocoding identifies the app and caches results', () async {
    var calls = 0;
    final api = SeoulOpenApi(
      apiKey: 'k',
      client: MockClient((request) async {
        calls += 1;
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.headers['User-Agent'], startsWith('seoul-safety-map/'));
        return http.Response(jsonEncode([{'lat': '37.55', 'lon': '126.99'}]), 200);
      }),
    );

    final first = await api.geocodeAddress('중구 삼일대로 231');
    final second = await api.geocodeAddress('중구 삼일대로 231');

    expect(first!.latitude, 37.55);
    expect(second, first);
    expect(calls, 1);
  });
}
