import 'package:latlong2/latlong.dart';

import 'models.dart';

class NearbyPoi {
  final PoiItem item;
  final double meters;
  const NearbyPoi(this.item, this.meters);
}

const Distance _distance = Distance();

/// The [perType] closest items of each type to [from], closest first.
/// Types are returned in [types] order and empty types are left out.
Map<PoiType, List<NearbyPoi>> nearestByType(
  Iterable<PoiItem> items,
  LatLng from, {
  int perType = 3,
  List<PoiType> types = const [PoiType.er, PoiType.toilet, PoiType.safeRoute, PoiType.park],
}) {
  final byType = <PoiType, List<NearbyPoi>>{};
  for (final item in items) {
    if (!types.contains(item.type)) continue;
    final meters = _distance.as(LengthUnit.Meter, from, item.point);
    (byType[item.type] ??= []).add(NearbyPoi(item, meters));
  }
  return {
    for (final type in types)
      if (byType[type] != null)
        type: (byType[type]!..sort((a, b) => a.meters.compareTo(b.meters))).take(perType).toList(),
  };
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

/// Kakao Map route link (opens the app if installed, otherwise the web).
Uri directionsUri(PoiItem item) {
  final name = item.title.replaceAll(',', ' ');
  return Uri.parse(
    'https://map.kakao.com/link/to/${Uri.encodeComponent(name)},${item.point.latitude},${item.point.longitude}',
  );
}
