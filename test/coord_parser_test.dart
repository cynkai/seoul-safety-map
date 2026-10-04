import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_safety_map/core/coord_parser.dart';

void main() {
  test('reads POINT WKT as (lon lat)', () {
    final p = parseLatLngFromRow({'POINT_WKT': 'POINT(126.978 37.5665)'});
    expect(p!.latitude, closeTo(37.5665, 1e-9));
    expect(p.longitude, closeTo(126.978, 1e-9));
  });

  test('reads park coordinates from XCRD/YCRD', () {
    // Shape of a SearchParkInfoService row; XCRD_G/YCRD_G are TM coordinates.
    final p = parseLatLngFromRow({
      'PARK_NM': '남산공원',
      'XCRD_G': '198364.107',
      'YCRD_G': '450395.554',
      'XCRD': '126.9903773',
      'YCRD': '37.5501402',
    });
    expect(p, isNotNull);
    expect(p!.latitude, closeTo(37.5501402, 1e-9));
    expect(p.longitude, closeTo(126.9903773, 1e-9));
  });

  test('reads toilet coordinates from COORD_X/COORD_Y', () {
    final p = parseLatLngFromRow({'COORD_X': '127.0276', 'COORD_Y': '37.4979'});
    expect(p!.latitude, closeTo(37.4979, 1e-9));
  });

  test('rejects coordinates outside Korea and rows without any', () {
    expect(parseLatLngFromRow({'LAT': '0', 'LON': '0'}), isNull);
    expect(parseLatLngFromRow({'PARK_ADDR': '서울특별시 중구'}), isNull);
    expect(parsePointWkt('LINESTRING(1 2, 3 4)'), isNull);
  });
}
