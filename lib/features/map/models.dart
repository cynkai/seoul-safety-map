import 'package:latlong2/latlong.dart';

enum PoiType {
  toilet,
  park,
  er,
  safeRoute;

  String get title => switch (this) {
        PoiType.toilet => '공중화장실',
        PoiType.park => '공원',
        PoiType.er => '응급실',
        PoiType.safeRoute => '안심귀갓길',
      };
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