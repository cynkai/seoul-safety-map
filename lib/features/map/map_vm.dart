import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:latlong2/latlong.dart' show Distance;

import '../../core/seoul_api.dart';
import '../../core/coord_parser.dart';
import 'models.dart';

class MapVm extends ChangeNotifier {
  final SeoulOpenApi api;
  MapVm({required this.api});

  bool showToilet = true;
  bool showPark = true;
  bool showEr = true;
  bool showSafeRoute = true;

  bool loading = false;
  bool backgroundLoading = false;

  String? error;

  LatLng center = const LatLng(37.5665, 126.9780);  // 서울로 고정
  LatLng? myLocation;

  double radiusKm = 0.5;
  final Distance _distance = const Distance();

  static const List<double> radiusOptions = [
    0.5,
    1,
    3,
    5,
    10,
    15,
    20,
    25,
    30,
  ];

  final List<String> selectedDistricts = [];

  List<PoiItem> toilet = [];
  List<PoiItem> park = [];
  List<PoiItem> er = [];
  List<PoiItem> safeRoute = [];

  String _filterCacheKey = '';
  List<PoiItem> _visibleCache = [];

  // 서울 판별 함수
  bool isInSeoul(LatLng p) {
    return p.latitude >= 37.40 && p.latitude <= 37.72 &&
        p.longitude >= 126.75 && p.longitude <= 127.20;
  }

  bool get isUserOutsideSeoul {
    if (myLocation == null) return false;
    return !isInSeoul(myLocation!);
  }

  // 위치 로딩 후 마커 필터링
  Future<void> initAndLoad() async {
    await initLocation();
    await loadAll();
  }

  Future<void> initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error = '위치 서비스가 꺼져 있습니다.';
        notifyListeners();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        error = '위치 권한이 거부되었습니다.';
        notifyListeners();
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        error = '위치 권한이 영구 거부되었습니다(설정에서 허용 필요).';
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      myLocation = LatLng(pos.latitude, pos.longitude);
      center = myLocation!;
      _invalidateVisibleCache();
      notifyListeners();
    } catch (e) {
      error = '위치 가져오기 실패: $e';
      notifyListeners();
    }
  }

  void setRadiusKm(double km) {
    radiusKm = km;
    _invalidateVisibleCache();
    notifyListeners();
  }

  String radiusLabel(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)}m';
    return '${km.toStringAsFixed(0)}km';
  }

  // 구 필터링
  String? extractDistrict(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final m = RegExp(r'([가-힣]+구)').firstMatch(text);
    return m?.group(1);
  }

  String? _resolveDistrict(
      Map<String, dynamic> row,
      String? address,
      String title,
      ) {
    final directCandidates = <String?>[
      row['GU_NAME']?.toString(),
      row['RGN']?.toString(),
      row['SGG_NAME']?.toString(),
      row['EMD_NM']?.toString(),
      row['PARK_ADDR']?.toString(),
      row['DUTYADDR']?.toString(),
      row['ADDR_NEW']?.toString(),
      row['ADDR_OLD']?.toString(),
      row['ADDR']?.toString(),
      row['ADRES']?.toString(),
      row['ADDRESS']?.toString(),
      row['ROAD_ADDR']?.toString(),
      address,
      title,
    ];

    for (final c in directCandidates) {
      final d = extractDistrict(c);
      if (d != null && d.isNotEmpty) return d;
    }

    for (final entry in row.entries) {
      final d = extractDistrict(entry.value?.toString());
      if (d != null && d.isNotEmpty) return d;
    }

    return null;
  }

  bool isErOpenNow(Map<String, dynamic> r, DateTime now) {
    final idx = now.weekday;
    final start = (r['DUTYTIME${idx}S'] ?? '').toString();
    final close = (r['DUTYTIME${idx}C'] ?? '').toString();

    int? toMin(String hhmm) {
      final s = hhmm.trim();
      if (s.length != 4) return null;
      final h = int.tryParse(s.substring(0, 2));
      final m = int.tryParse(s.substring(2, 4));
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    final sMin = toMin(start);
    final cMin = toMin(close);
    if (sMin == null || cMin == null) return false;

    final nowMin = now.hour * 60 + now.minute;

    if (cMin >= sMin) {
      return nowMin >= sMin && nowMin <= cMin;
    }
    return nowMin >= sMin || nowMin <= cMin;
  }

  String _makeFilterCacheKey() {
    final loc = myLocation == null
        ? 'noloc'
        : '${myLocation!.latitude.toStringAsFixed(5)},${myLocation!.longitude.toStringAsFixed(5)}';

    return [
      loc,
      radiusKm.toStringAsFixed(2),
      showToilet,
      showPark,
      showEr,
      showSafeRoute,
      selectedDistricts.join('|'),
      toilet.length,
      park.length,
      er.length,
      safeRoute.length,
    ].join('_');
  }

  void _invalidateVisibleCache() {
    _filterCacheKey = '';
  }

  List<PoiItem> get visibleItems {
    final key = _makeFilterCacheKey();
    if (_filterCacheKey == key) return _visibleCache;

    final base = <PoiItem>[];
    if (showToilet) base.addAll(toilet);
    if (showPark) base.addAll(park);
    if (showEr) base.addAll(er);
    if (showSafeRoute) base.addAll(safeRoute);

    if (myLocation == null) {
      _filterCacheKey = key;
      _visibleCache = [];
      return _visibleCache;
    }

    // 서울 밖이면 마커 표시 안 함
    if (isUserOutsideSeoul && selectedDistricts.isEmpty) {
      _filterCacheKey = key;
      _visibleCache = [];
      return _visibleCache;
    }

    final inRadius = <PoiItem>[];
    for (final item in base) {
      final meters = _distance.as(LengthUnit.Meter, myLocation!, item.point);
      if (meters <= radiusKm * 1000) {
        inRadius.add(item);
      }
    }

    if (selectedDistricts.isEmpty) {
      _filterCacheKey = key;
      _visibleCache = inRadius;
      return _visibleCache;
    }

    final extraByDistrict = <PoiItem>[];
    for (final item in base) {
      final d = item.district;
      if (d != null && selectedDistricts.contains(d)) {
        extraByDistrict.add(item);
      }
    }

    final seen = <String>{};
    final merged = <PoiItem>[];

    for (final item in [...inRadius, ...extraByDistrict]) {
      if (seen.add(item.id)) {
        merged.add(item);
      }
    }

    _filterCacheKey = key;
    _visibleCache = merged;
    return _visibleCache;
  }

  void toggleToilet(bool v) {
    showToilet = v;
    _invalidateVisibleCache();
    notifyListeners();
  }

  void togglePark(bool v) {
    showPark = v;
    _invalidateVisibleCache();
    notifyListeners();
  }

  void toggleEr(bool v) {
    showEr = v;
    _invalidateVisibleCache();
    notifyListeners();
  }

  void toggleSafeRoute(bool v) {
    showSafeRoute = v;
    _invalidateVisibleCache();
    notifyListeners();
  }

  void addDistrict(String gu) {
    if (!selectedDistricts.contains(gu)) {
      selectedDistricts.add(gu);
      _invalidateVisibleCache();
      notifyListeners();
    }
  }

  void removeDistrict(String gu) {
    selectedDistricts.remove(gu);
    _invalidateVisibleCache();
    notifyListeners();
  }

  String get activeDistrictLabel {
    if (isUserOutsideSeoul && selectedDistricts.isEmpty) {
      return '현재 서울 지역 아님. 구 추가로 지역을 선택해 주세요.';
    }

    if (selectedDistricts.isEmpty) return '선택 구 없음';
    return '추가된 구: ${selectedDistricts.join(', ')}';
  }

  Future<void> loadAll() async {
    loading = true;
    backgroundLoading = false;
    error = null;
    notifyListeners();

    try {
      final firstBatch = await Future.wait<List<Map<String, dynamic>>>([
        api.fetchAllRows(
          service: 'mgisToiletPoi',
          limit: 1500,
          debugPrint: true,
        ),
        api.fetchAllRows(
          service: 'TvEmgcHospitalInfo',
          limit: 200,
          debugPrint: true,
        ),
        api.fetchAllRows(
          service: 'SearchParkInfoService',
          limit: 133,
          debugPrint: true,
        ),
        api.fetchAllRows(
          service: 'tbSafeReturnItem',
          limit: 1500,
          debugPrint: true,
        ),
      ]);

      final toiletRows = firstBatch[0];
      final erRows = firstBatch[1];
      final parkRows = firstBatch[2];
      final safeRouteRows = firstBatch[3];

      toilet = _rowsToPoi(toiletRows, PoiType.toilet);
      er = _rowsToPoi(erRows, PoiType.er);
      park = await _rowsToPoiWithGeocode(parkRows, PoiType.park);
      safeRoute = _rowsToPoi(safeRouteRows, PoiType.safeRoute);

      loading = false;
      backgroundLoading = false;
      _invalidateVisibleCache();
      notifyListeners();
    } catch (e) {
      loading = false;
      backgroundLoading = false;
      error = '데이터 로딩 실패: $e';
      notifyListeners();
    }
  }

  Future<void> _loadSafeRouteOnly() async {
    try {
      final safeRouteRows = await api.fetchAllRows(
        service: 'tbSafeReturnItem',
        limit: 1500,
        debugPrint: true,
      );

      safeRoute = _rowsToPoi(safeRouteRows, PoiType.safeRoute);
      _invalidateVisibleCache();
    } catch (e) {
      error = '안심귀갓길 로딩 실패: $e';
    } finally {
      backgroundLoading = false;
      notifyListeners();
    }
  }

  Future<List<PoiItem>> _rowsToPoiWithGeocode(
      List<Map<String, dynamic>> rows,
      PoiType type,
      ) async {
    final list = <PoiItem>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      LatLng? latlng = parseLatLngFromRow(row);

      if (latlng == null) {
        final address = _pickAddress(row, type);
        if (address != null && address.trim().isNotEmpty) {
          latlng = await api.geocodeAddress(address);
        }
      }

      if (latlng == null) continue;

      final title = _pickTitle(row, type);
      final address = _pickAddress(row, type);
      final district = _resolveDistrict(row, address, title);

      list.add(
        PoiItem(
          id: _buildId(row, type, i),
          type: type,
          point: latlng,
          title: title,
          address: address,
          district: district,
          extra: row,
        ),
      );
    }

    return list;
  }

  List<PoiItem> _rowsToPoi(List<Map<String, dynamic>> rows, PoiType type) {
    final list = <PoiItem>[];

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final latlng = parseLatLngFromRow(row);
      if (latlng == null) continue;

      final title = _pickTitle(row, type);
      final address = _pickAddress(row, type);
      final district = _resolveDistrict(row, address, title);

      list.add(
        PoiItem(
          id: _buildId(row, type, i),
          type: type,
          point: latlng,
          title: title,
          address: address,
          district: district,
          extra: row,
        ),
      );
    }

    return list;
  }

  String _buildId(Map<String, dynamic> row, PoiType type, int index) {
    switch (type) {
      case PoiType.toilet:
        return (row['OBJECTID'] ?? row['POI_ID'] ?? 'toilet_$index').toString();
      case PoiType.park:
        return (row['SN'] ?? 'park_$index').toString();
      case PoiType.er:
        return (row['HPID'] ?? 'er_$index').toString();
      case PoiType.safeRoute:
        return (row['FACI_ID'] ?? row['ASG_ID'] ?? 'safe_$index').toString();
    }
  }

  String _pickTitle(Map<String, dynamic> row, PoiType type) {
    switch (type) {
      case PoiType.toilet:
        return ((row['CONTS_NAME'] ?? row['FNAME'] ?? '화장실').toString().trim())
            .ifEmpty('화장실');
      case PoiType.park:
        return ((row['PARK_NM'] ?? '공원').toString().trim()).ifEmpty('공원');
      case PoiType.er:
        return ((row['DUTYNAME'] ?? '응급실').toString().trim()).ifEmpty('응급실');
      case PoiType.safeRoute:
        return ((row['ASG_NM'] ?? row['FACI_ID'] ?? '안심귀갓길').toString().trim())
            .ifEmpty('안심귀갓길');
    }
  }

  String? _pickAddress(Map<String, dynamic> row, PoiType type) {
    switch (type) {
      case PoiType.toilet:
        return (row['ADDR_NEW'] ?? row['ADDR_OLD'])?.toString().trim();
      case PoiType.park:
        return (row['PARK_ADDR'] ?? row['ADDR'] ?? row['ADDRESS'])
            ?.toString()
            .trim();
      case PoiType.er:
        return (row['DUTYADDR'] ?? row['ADDR'] ?? row['ADDRESS'])
            ?.toString()
            .trim();
      case PoiType.safeRoute:
        return (row['DELOC'] ?? row['EMD_NM'] ?? row['SGG_NAME'])
            ?.toString()
            .trim();
    }
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}