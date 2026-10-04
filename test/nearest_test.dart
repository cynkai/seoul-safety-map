import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:seoul_safety_map/features/map/models.dart';
import 'package:seoul_safety_map/features/map/nearest.dart';

PoiItem poi(String id, PoiType type, double lat, double lon) => PoiItem(
      id: id,
      type: type,
      point: LatLng(lat, lon),
      title: id,
      address: null,
      district: null,
      extra: null,
    );

void main() {
  safeRouteTests();
  const cityHall = LatLng(37.5665, 126.9780);

  test('returns the closest items per type, nearest first', () {
    final items = [
      poi('toilet-far', PoiType.toilet, 37.60, 126.97),
      poi('toilet-near', PoiType.toilet, 37.5670, 126.9780),
      poi('toilet-mid', PoiType.toilet, 37.57, 126.98),
      poi('toilet-farthest', PoiType.toilet, 37.70, 126.90),
      poi('er-1', PoiType.er, 37.58, 126.99),
    ];

    final result = nearestByType(items, cityHall);

    expect(result.keys, [PoiType.er, PoiType.toilet]); // ER first, empty types left out
    expect(result[PoiType.toilet]!.map((n) => n.item.id), ['toilet-near', 'toilet-mid', 'toilet-far']);
    expect(result[PoiType.toilet]!.first.meters, closeTo(55.6, 1));
  });

  test('perType limits the list', () {
    final items = [for (var i = 0; i < 5; i++) poi('t$i', PoiType.toilet, 37.5665 + i * 0.001, 126.978)];
    expect(nearestByType(items, cityHall, perType: 2)[PoiType.toilet], hasLength(2));
  });

  test('formats distances', () {
    expect(formatDistance(56.4), '56m');
    expect(formatDistance(1234), '1.2km');
  });

  test('builds a Kakao Map route link to the facility', () {
    final uri = directionsUri(poi('서울시청, 본관', PoiType.park, 37.5665, 126.978));
    expect(uri.toString(), startsWith('https://map.kakao.com/link/to/'));
    expect(Uri.decodeComponent(uri.toString()), contains('서울시청  본관,37.5665,126.978'));
  });
}

PoiItem safe(String id, String code, double lat) => PoiItem(
      id: id,
      type: PoiType.safeRoute,
      point: LatLng(lat, 126.978),
      title: id,
      address: null,
      district: null,
      extra: {'FACI_CODE': code},
    );

void safeRouteTests() {
  const cityHall = LatLng(37.5665, 126.9780);

  test('safe-return facilities: only emergency bells and CCTV count as nearest', () {
    final result = nearestByType([
      safe('streetlight', '305', 37.5666), // closest, but a streetlight
      safe('road-marking', '304', 37.5667),
      safe('cctv', '302', 37.5670),
      safe('bell', '301', 37.5680),
    ], cityHall);
    expect(result[PoiType.safeRoute]!.map((n) => n.item.id), ['cctv', 'bell']);
  });

  test('names safe-return facilities by code', () {
    expect(safeFacilityName({'FACI_CODE': '301'}), '안심벨');
    expect(safeFacilityName({'FACI_CODE': '305'}), '보안등');
    expect(safeFacilityName({'FACI_CODE': '308', 'REMARK': '안심반사경'}), '안심반사경');
    expect(safeFacilityName({'FACI_CODE': '999'}), '안심귀갓길 시설');
  });
}
