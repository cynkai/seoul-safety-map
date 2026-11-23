import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:seoul_safety_map/core/seoul_api.dart';
import 'package:seoul_safety_map/features/map/map_vm.dart';
import 'package:seoul_safety_map/features/map/models.dart';

class _TestApi extends SeoulOpenApi {
  final services = <String>[];

  _TestApi() : super(apiKey: 'unused');

  @override
  Future<List<Map<String, dynamic>>> fetchAllRows({
    required String service,
    int? limit,
    int pageSize = 1000,
  }) async {
    services.add(service);
    return [];
  }
}

class _PendingLocationVm extends MapVm {
  final position = Completer<void>();

  _PendingLocationVm({required super.api});

  @override
  Future<void> initLocation() => position.future;
}

PoiItem _poi(PoiType type, String id, String district, LatLng point) {
  return PoiItem(
    id: id,
    type: type,
    point: point,
    title: type.title,
    address: null,
    district: district,
    extra: null,
  );
}

void main() {
  final vm = MapVm(api: SeoulOpenApi(apiKey: 'unused'));

  // Shape of a TvEmgcHospitalInfo row: an emergency room with 09:00-17:00
  // outpatient hours on Mondays.
  final hospital = {
    'DUTYNAME': '테스트병원',
    'DUTYERYN': '1',
    'DUTYTIME1S': '0900',
    'DUTYTIME1C': '1700',
  };

  test('an emergency room is operating whatever the clinic hours say', () {
    expect(vm.erOperating(hospital), isTrue);
    expect(vm.erOperating({'DUTYERYN': '2'}), isFalse);
    expect(vm.erOperating({}), isFalse);
  });

  test('outpatient hours are only clinic hours', () {
    final mondayNight = DateTime(2026, 10, 5, 23, 0); // a Monday
    final mondayNoon = DateTime(2026, 10, 5, 12, 0);
    expect(vm.isOutpatientOpenNow(hospital, mondayNoon), isTrue);
    expect(vm.isOutpatientOpenNow(hospital, mondayNight), isFalse);
    expect(vm.erOperating(hospital), isTrue); // still an operating ER at night
  });

  test('extracts the district from an address', () {
    expect(vm.extractDistrict('서울특별시 중구 삼일대로 231'), '중구');
    expect(vm.extractDistrict('경기도 과천시'), isNull);
  });

  test('facility load starts while location permission is pending', () async {
    final api = _TestApi();
    final pending = _PendingLocationVm(api: api);
    addTearDown(pending.dispose);
    final ready = pending.initAndLoad();
    expect(api.services, hasLength(4));
    expect(pending.position.isCompleted, isFalse);
    pending.position.complete();
    await ready;
    expect(pending.loading, isFalse);
  });

  group('district browsing', () {
    final center = const LatLng(37.5665, 126.9780);
    final toilet = _poi(PoiType.toilet, 'same-id', '중구', center);
    final park = _poi(PoiType.park, 'same-id', '중구', center);
    final er = _poi(PoiType.er, 'er', '종로구', const LatLng(37.567, 126.978));
    late MapVm filters;

    setUp(() {
      filters = MapVm(api: _TestApi())
        ..toilet = [toilet]
        ..park = [park]
        ..er = [er];
    });
    tearDown(() => filters.dispose());

    test(
      'loads selected districts with no location and respects type filters',
      () {
        expect(filters.canFilterByRadius, isFalse);
        expect(filters.visibleItems, isEmpty);
        filters.addDistrict('중구');
        expect(filters.visibleItems, [toilet, park]);
        filters.toggleToilet(false);
        expect(filters.visibleItems, [park]);
        filters.removeDistrict('중구');
        expect(filters.visibleItems, isEmpty);
      },
    );

    test('combines nearby and district facilities without duplicates', () {
      filters.myLocation = center;
      expect(filters.canFilterByRadius, isTrue);
      expect(filters.visibleItems, [toilet, park, er]);
      filters.addDistrict('중구');
      expect(filters.visibleItems, [toilet, park, er]);
    });

    test('outside Seoul, only the selected district is shown', () {
      filters.myLocation = const LatLng(37.39, 126.978);
      filters.setRadiusKm(30);
      filters.addDistrict('종로구');
      expect(filters.canFilterByRadius, isFalse);
      expect(filters.visibleItems, [er]);
    });
  });
}
