import 'package:latlong2/latlong.dart';

LatLng? parseLatLngFromRow(Map<String, dynamic> row) {
  final pointWkt = (row['POINT_WKT'] ?? '').toString().trim();
  if (pointWkt.isNotEmpty) {
    final fromWkt = parsePointWkt(pointWkt);
    if (fromWkt != null) return fromWkt;
  }

  return _tryDirectLatLng(row);
}

LatLng? parsePointWkt(String wkt) {
  final m = RegExp(
    r'POINT\s*\(\s*([0-9.\-]+)\s+([0-9.\-]+)\s*\)',
    caseSensitive: false,
  ).firstMatch(wkt);

  if (m == null) return null;

  final x = double.tryParse(m.group(1)!);
  final y = double.tryParse(m.group(2)!);

  if (x == null || y == null) return null;

  return LatLng(y, x);
}

LatLng? _tryDirectLatLng(Map<String, dynamic> row) {
  const latKeys = [
    'Y_WGS84',
    'WGS84LAT',
    'COORD_Y',
    'LAT',
    'WGSYPT',
    'Y',
    'y',
    'latitude',
    'Latitude',
  ];

  const lonKeys = [
    'X_WGS84',
    'WGS84LON',
    'COORD_X',
    'LON',
    'WGSXPT',
    'X',
    'x',
    'longitude',
    'Longitude',
  ];
  for (final latKey in latKeys) {
    for (final lonKey in lonKeys) {
      final lat = double.tryParse((row[latKey] ?? '').toString());
      final lon = double.tryParse((row[lonKey] ?? '').toString());

      if (lat == null || lon == null) continue;
      if (lat < 33 || lat > 39) continue;
      if (lon < 124 || lon > 132) continue;

      return LatLng(lat, lon);
    }
  }

  return null;
}