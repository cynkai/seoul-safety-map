import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_safety_map/core/seoul_api.dart';
import 'package:seoul_safety_map/features/map/map_vm.dart';

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
}
