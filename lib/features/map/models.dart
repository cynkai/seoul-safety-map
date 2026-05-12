import 'package:latlong2/latlong.dart';

enum PoiType {
  toilet,
  park,
  er,
  safeRoute,
}

class PoiItem {
  final String id;
  final PoiType type;
  final LatLng point;
  final String title;
  final String? address;
  final String? district;
  final Map<String, dynamic>? extra;

  PoiItem({
    required this.id,
    required this.type,
    required this.point,
    required this.title,
    required this.address,
    required this.district,
    required this.extra,
  });
}