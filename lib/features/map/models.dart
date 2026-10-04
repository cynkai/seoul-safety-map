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
/// Safe-return-route facility codes (FACI_CODE in tbSafeReturnItem), from
/// "안심귀갓길_안전시설물(코드유형).xlsx" on data.seoul.go.kr (OA-21696).
const Map<String, String> safeFacilityNames = {
  '301': '안심벨',
  '302': 'CCTV',
  '303': '안내표지판',
  '304': '노면표기',
  '305': '보안등',
  '306': '서비스 안내판',
  '307': '112 위치 신고 안내',
  '308': '기타 시설',
};

/// Facilities you can walk to and use in an emergency.
const Set<String> emergencySafeFacilityCodes = {'301', '302'};

/// Display name of a safe-return facility row; code 308 uses its remark.
String safeFacilityName(Map<String, dynamic> row) {
  final code = (row['FACI_CODE'] ?? '').toString().trim();
  final remark = (row['REMARK'] ?? '').toString().trim();
  if (code == '308' && remark.isNotEmpty) return remark;
  return safeFacilityNames[code] ?? '안심귀갓길 시설';
}
