import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_vm.dart';
import 'models.dart';

const List<String> seoulGuList = [
  '강남구',
  '강동구',
  '강북구',
  '강서구',
  '관악구',
  '광진구',
  '구로구',
  '금천구',
  '노원구',
  '도봉구',
  '동대문구',
  '동작구',
  '마포구',
  '서대문구',
  '서초구',
  '성동구',
  '성북구',
  '송파구',
  '양천구',
  '영등포구',
  '용산구',
  '은평구',
  '종로구',
  '중구',
  '중랑구',
];

class _IconBadgeClusterMarker {
  static Widget toilet({required int count}) {
    return _buildMarker(
      icon: Icons.wc,
      count: count,
      bgColor: const Color(0xFFF2FFF4),
      borderColor: const Color(0xFF1B8B3A),
      iconColor: const Color(0xFF1B8B3A),
    );
  }

  static Widget park({required int count}) {
    return _buildMarker(
      icon: Icons.park,
      count: count,
      bgColor: const Color(0xFFFFF7CC),
      borderColor: const Color(0xFFFFB300),
      iconColor: const Color(0xFFFF8F00),
    );
  }

  static Widget er({required int count}) {
    return _buildMarker(
      icon: Icons.local_hospital,
      count: count,
      bgColor: const Color(0xFFFFE6E6),
      borderColor: const Color(0xFFE53935),
      iconColor: const Color(0xFFE53935),
    );
  }

  static Widget safeRoute({required int count}) {
    return _buildMarker(
      icon: Icons.videocam,
      count: count,
      bgColor: const Color(0xFF1976D2),
      borderColor: const Color(0xFF0D47A1),
      iconColor: Colors.white,
    );
  }

  static Widget _buildMarker({
    required IconData icon,
    required int count,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1.8),
            ),
            child: Center(
              child: Icon(icon, size: 22, color: iconColor),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  final MapVm vm;

  const MapPage({
    super.key,
    required this.vm,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  double _zoom = 13;

  static const Color _purple = Color(0xFF6F42C1);
  static const Color _beige = Color(0xFFEAD8B7);
  static const Color _safeRouteBlue = Color(0xFF1976D2);

  String _markerCacheKey = '';
  List<Marker> _cachedToiletMarkers = [];
  List<Marker> _cachedParkMarkers = [];
  List<Marker> _cachedErMarkers = [];
  List<Marker> _cachedSafeRouteMarkers = [];

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
    widget.vm.initAndLoad();
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _zoomIn() {
    final center = _mapController.camera.center;
    final newZoom = (_zoom + 1).clamp(1.0, 19.0);
    _mapController.move(center, newZoom);
    setState(() => _zoom = newZoom);
  }

  void _zoomOut() {
    final center = _mapController.camera.center;
    final newZoom = (_zoom - 1).clamp(1.0, 19.0);
    _mapController.move(center, newZoom);
    setState(() => _zoom = newZoom);
  }

  Future<void> _goMyLocation() async {
    await widget.vm.initLocation();

    final myLocation = widget.vm.myLocation;
    if (myLocation == null) return;

    _mapController.move(myLocation, _zoom);
  }

  Future<void> _showRadiusPicker() async {
    final vm = widget.vm;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: MapVm.radiusOptions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final km = MapVm.radiusOptions[index];
              final selected = vm.radiusKm == km;

              return ListTile(
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? _purple : Colors.black38,
                ),
                title: Text(
                  vm.radiusLabel(km),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? _purple : Colors.black87,
                  ),
                ),
                onTap: () {
                  vm.setRadiusKm(km);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  String get activeDistrictLabel {
    final vm = widget.vm;

    if (vm.isUserOutsideSeoul && vm.selectedDistricts.isEmpty) {
      return '현재 서울 지역 아님. 구 추가로 지역을 선택해 주세요.';
    }

    if (vm.selectedDistricts.isEmpty) {
      return '선택 구 없음';
    }

    return '추가된 구: ${vm.selectedDistricts.join(', ')}';
  }

  String _makeMarkerCacheKey(List<PoiItem> items) {
    return items.map((e) => '${e.type.name}_${e.id}').join('|');
  }

  void _rebuildMarkerCacheIfNeeded(List<PoiItem> items) {
    final key = _makeMarkerCacheKey(items);
    if (_markerCacheKey == key) return;

    final toilet = <Marker>[];
    final park = <Marker>[];
    final er = <Marker>[];
    final safeRoute = <Marker>[];

    for (final item in items) {
      final marker = _poiToMarker(context, item);

      switch (item.type) {
        case PoiType.toilet:
          toilet.add(marker);
          break;
        case PoiType.park:
          park.add(marker);
          break;
        case PoiType.er:
          er.add(marker);
          break;
        case PoiType.safeRoute:
          safeRoute.add(marker);
          break;
      }
    }

    _markerCacheKey = key;
    _cachedToiletMarkers = toilet;
    _cachedParkMarkers = park;
    _cachedErMarkers = er;
    _cachedSafeRouteMarkers = safeRoute;
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final items = vm.visibleItems;

    _rebuildMarkerCacheIfNeeded(items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('서울 안전 인프라 지도 (베타)'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: vm.center,
              initialZoom: _zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onPositionChanged: (pos, hasGesture) {
                final z = pos.zoom;
                if (z != null && z != _zoom) {
                  setState(() => _zoom = z);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.university',
              ),
              if (vm.myLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: vm.myLocation!,
                      radius: vm.radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.12),
                      borderColor: Colors.blue.withOpacity(0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              _clusterLayer(
                markers: _cachedToiletMarkers,
                builder: (count) {
                  return _IconBadgeClusterMarker.toilet(count: count);
                },
              ),
              _clusterLayer(
                markers: _cachedParkMarkers,
                builder: (count) {
                  return _IconBadgeClusterMarker.park(count: count);
                },
              ),
              _clusterLayer(
                markers: _cachedErMarkers,
                builder: (count) {
                  return _IconBadgeClusterMarker.er(count: count);
                },
              ),
              _clusterLayer(
                markers: _cachedSafeRouteMarkers,
                builder: (count) {
                  return _IconBadgeClusterMarker.safeRoute(count: count);
                },
              ),
              if (vm.myLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: vm.myLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fab(
                    hero: 'zoom_in',
                    icon: Icons.add,
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 10),
                  _fab(
                    hero: 'zoom_out',
                    icon: Icons.remove,
                    onTap: _zoomOut,
                  ),
                  const SizedBox(height: 10),
                  _fab(
                    hero: 'my_loc',
                    icon: Icons.my_location,
                    onTap: _goMyLocation,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final selected =
                            await showModalBottomSheet<String>(
                              context: context,
                              showDragHandle: true,
                              builder: (_) {
                                return SafeArea(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: seoulGuList.length,
                                    itemBuilder: (context, index) {
                                      final gu = seoulGuList[index];

                                      return ListTile(
                                        title: Text(gu),
                                        onTap: () {
                                          Navigator.pop(context, gu);
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            );

                            if (selected != null) {
                              widget.vm.addDistrict(selected);
                            }
                          },
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _beige,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD3BE96),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_city,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '구 추가',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.radar, size: 18),
                        label: Text(
                          '반경 ${widget.vm.radiusLabel(widget.vm.radiusKm)}',
                        ),
                        onPressed: _showRadiusPicker,
                        side: BorderSide(
                          color: _purple.withOpacity(0.35),
                        ),
                        backgroundColor: _purple.withOpacity(0.08),
                        labelStyle: const TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      FilterChip(
                        label: const Text('공중화장실'),
                        selected: widget.vm.showToilet,
                        onSelected: widget.vm.toggleToilet,
                      ),
                      FilterChip(
                        label: const Text('공원'),
                        selected: widget.vm.showPark,
                        onSelected: widget.vm.togglePark,
                      ),
                      FilterChip(
                        label: const Text('응급실'),
                        selected: widget.vm.showEr,
                        onSelected: widget.vm.toggleEr,
                      ),
                      FilterChip(
                        label: const Text('안심귀갓길'),
                        selected: widget.vm.showSafeRoute,
                        onSelected: widget.vm.toggleSafeRoute,
                      ),
                      for (final gu in widget.vm.selectedDistricts)
                        InputChip(
                          label: Text(gu),
                          onDeleted: () {
                            widget.vm.removeDistrict(gu);
                          },
                        ),
                      _CurrentCountText(vm: widget.vm),
                      if (widget.vm.loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (widget.vm.backgroundLoading)
                        const Text(
                          '안심귀갓길 로딩중',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (widget.vm.error != null)
                        Text(
                          widget.vm.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      Text(
                        activeDistrictLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fab({
    required String hero,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FloatingActionButton.small(
      heroTag: hero,
      backgroundColor: _purple,
      onPressed: onTap,
      child: Icon(
        icon,
        color: Colors.white,
      ),
    );
  }

  Widget _clusterLayer({
    required List<Marker> markers,
    required Widget Function(int count) builder,
  }) {
    if (markers.isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        markers: markers,
        maxClusterRadius: 45,
        size: const Size(44, 44),
        builder: (context, clusterMarkers) {
          return builder(clusterMarkers.length);
        },
      ),
    );
  }

  Marker _poiToMarker(BuildContext context, PoiItem item) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;
    String typeTitle;

    switch (item.type) {
      case PoiType.toilet:
        bg = const Color(0xFFF2FFF4);
        border = const Color(0xFF1B8B3A);
        iconColor = const Color(0xFF1B8B3A);
        icon = Icons.wc;
        typeTitle = '공중화장실';
        break;
      case PoiType.park:
        bg = const Color(0xFFFFF7CC);
        border = const Color(0xFFFFB300);
        iconColor = const Color(0xFFFF8F00);
        icon = Icons.park;
        typeTitle = '공원';
        break;
      case PoiType.er:
        bg = const Color(0xFFFFE6E6);
        border = const Color(0xFFE53935);
        iconColor = const Color(0xFFE53935);
        icon = Icons.local_hospital;
        typeTitle = '응급실';
        break;
      case PoiType.safeRoute:
        bg = _safeRouteBlue;
        border = const Color(0xFF0D47A1);
        iconColor = Colors.white;
        icon = Icons.videocam;
        typeTitle = '안심귀갓길';
        break;
    }

    final uniqueKey = '${item.type.name}_${item.id}';

    return Marker(
      key: ValueKey(uniqueKey),
      point: item.point,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () {
          _openDetailDialog(context, item, typeTitle);
        },
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: border,
              width: 1.8,
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Future<void> _openDetailDialog(
      BuildContext context,
      PoiItem item,
      String typeTitle,
      ) async {
    final vm = widget.vm;
    String detail = '';
    String? tel;
    String? url;
    bool isErOpen = false;

    if (item.type == PoiType.er) {
      final r = item.extra ?? {};
      tel = _pickPhone([r['DUTYTEL3'], r['DUTYTEL1']]);
      isErOpen = r.isNotEmpty ? vm.isErOpenNow(r, DateTime.now()) : false;
      detail = _formatErDetail(item);
    } else if (item.type == PoiType.park) {
      final r = item.extra ?? {};
      tel = _pickPhone([r['TELNO']]);
      url = _pickUrl([r['URL']]);
      detail = _formatParkDetail(item);
    } else if (item.type == PoiType.toilet) {
      final r = item.extra ?? {};
      tel = _pickPhone([r['TEL_NO']]);
      detail = _formatToiletDetail(item);
    } else if (item.type == PoiType.safeRoute) {
      final r = item.extra ?? {};
      tel = _pickPhone([r['INST_TELNO']]);
      detail = _formatSafeRouteDetail(item);
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(typeTitle),
              ),
              if (item.type == PoiType.er && isErOpen)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '운영중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.green[800],
                    ),
                  ),
                ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(detail),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('닫기'),
            ),
            if (url != null)
              FilledButton.icon(
                onPressed: () {
                  _openUrl(url!);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('바로가기'),
              ),
            if (tel != null)
              FilledButton.icon(
                onPressed: () {
                  _callPhone(tel!);
                },
                icon: const Icon(Icons.call),
                label: const Text('전화'),
              ),
          ],
        );
      },
    );
  }

  String? _pickPhone(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isEmpty) continue;

      final cleaned = s.replaceAll(RegExp(r'[^0-9 -]'), '').trim();
      if (cleaned.isEmpty) continue;

      return cleaned;
    }

    return null;
  }

  String? _pickUrl(List<dynamic> candidates) {
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isEmpty) continue;

      if (s.startsWith('http://') || s.startsWith('https://')) {
        return s;
      }
    }

    return null;
  }

  Future<void> _callPhone(String tel) async {
    final uri = Uri(
      scheme: 'tel',
      path: tel,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  String _formatErDetail(PoiItem item) {
    final r = item.extra ?? {};

    String fmt(String hhmm) {
      final s = hhmm.trim();
      if (s.length != 4) return s;

      return '${s.substring(0, 2)}:${s.substring(2, 4)}';
    }

    String line(int i, String label) {
      final s = (r['DUTYTIME${i}S'] ?? '').toString();
      final c = (r['DUTYTIME${i}C'] ?? '').toString();

      if (s.isEmpty && c.isEmpty) {
        return '$label: 정보없음';
      }

      return '$label: ${fmt(s)} ~ ${fmt(c)}';
    }

    final lines = <String>[
      item.title,
      if ((item.address ?? '').isNotEmpty) '주소: ${item.address!}',
      if ((r['DUTYEMCLSNAME'] ?? '').toString().trim().isNotEmpty)
        '분류: ${(r['DUTYEMCLSNAME'] ?? '').toString().trim()}',
      if ((r['DUTYERYN'] ?? '').toString().trim().isNotEmpty)
        '응급실운영: ${(r['DUTYERYN'] ?? '').toString().trim()}',
      if ((r['DUTYTEL1'] ?? '').toString().trim().isNotEmpty)
        '대표전화: ${(r['DUTYTEL1'] ?? '').toString().trim()}',
      if ((r['DUTYTEL3'] ?? '').toString().trim().isNotEmpty)
        '응급실전화: ${(r['DUTYTEL3'] ?? '').toString().trim()}',
      '',
      line(1, '월'),
      line(2, '화'),
      line(3, '수'),
      line(4, '목'),
      line(5, '금'),
      line(6, '토'),
      line(7, '일'),
      line(8, '공휴일'),
    ];

    return lines.join('\n');
  }

  String _formatParkDetail(PoiItem item) {
    final r = item.extra ?? {};

    String pick(dynamic v) {
      return (v ?? '').toString().trim();
    }

    final lines = <String>[
      '공원명: ${pick(r['PARK_NM']).isNotEmpty ? pick(r['PARK_NM']) : item.title}',
      if (pick(r['MAIN_FCLT']).isNotEmpty) '주요시설: ${pick(r['MAIN_FCLT'])}',
      if (pick(r['MAIN_PLNT']).isNotEmpty) '주요식물: ${pick(r['MAIN_PLNT'])}',
      if ((item.address ?? '').isNotEmpty) '공원주소: ${item.address!}',
      if (pick(r['MNG_DEPT']).isNotEmpty) '관리부서: ${pick(r['MNG_DEPT'])}',
      if (pick(r['TELNO']).isNotEmpty) '전화번호: ${pick(r['TELNO'])}',
      if (pick(r['URL']).isNotEmpty) '홈페이지: ${pick(r['URL'])}',
    ];

    return lines.join('\n');
  }

  String _formatToiletDetail(PoiItem item) {
    final r = item.extra ?? {};

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = (r[key] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }

      return '';
    }

    String clean(String value) {
      return value.replaceAll('|', ' / ').trim();
    }

    final buildingName = pick(['CONTS_NAME', 'FNAME']);
    final roadAddr = pick(['ADDR_NEW']);
    final oldAddr = pick(['ADDR_OLD']);
    final guName = pick(['GU_NAME']);
    final tel = pick(['TEL_NO']);
    final type = clean(pick(['VALUE_01', 'ANAME']));
    final openTime = clean(pick(['VALUE_02']));
    final toiletStatus = clean(pick(['VALUE_04', 'CNAME']));
    final disabledStatus = clean(pick(['VALUE_05']));
    final guideSign = clean(pick(['VALUE_07']));
    final etc = clean(pick(['VALUE_08', 'VALUE_09']));
    final insertDate = pick(['INSERTDATE']);
    final updateDate = pick(['UPDATEDATE']);

    final lines = <String>[
      '건물명: ${buildingName.isNotEmpty ? buildingName : item.title}',
      if (roadAddr.isNotEmpty) '도로명주소: $roadAddr',
      if (oldAddr.isNotEmpty) '지번주소: $oldAddr',
      if (guName.isNotEmpty) '구 명칭: $guName',
      if (tel.isNotEmpty) '전화번호: $tel',
      if (type.isNotEmpty) '유형: $type',
      if (openTime.isNotEmpty) '개방시간: $openTime',
      if (toiletStatus.isNotEmpty) '화장실 현황: $toiletStatus',
      if (disabledStatus.isNotEmpty) '장애인화장실 현황: $disabledStatus',
      if (guideSign.isNotEmpty) '안내표지: $guideSign',
      if (etc.isNotEmpty) '기타: $etc',
      if (insertDate.isNotEmpty) '등록일: $insertDate',
      if (updateDate.isNotEmpty) '수정일: $updateDate',
    ];

    return lines.join('\n');
  }

  String _formatSafeRouteDetail(PoiItem item) {
    final r = item.extra ?? {};

    String pick(dynamic v) {
      return (v ?? '').toString().trim();
    }

    final lines = <String>[
      '귀갓길명: ${pick(r['ASG_NM']).isNotEmpty ? pick(r['ASG_NM']) : item.title}',
      if (pick(r['SGG_NAME']).isNotEmpty) '시군구: ${pick(r['SGG_NAME'])}',
      if (pick(r['EMD_NM']).isNotEmpty) '읍면동: ${pick(r['EMD_NM'])}',
      if (pick(r['DELOC']).isNotEmpty) '세부위치: ${pick(r['DELOC'])}',
      if (pick(r['INSTL_CNT']).isNotEmpty) '설치대수: ${pick(r['INSTL_CNT'])}',
      if (pick(r['INST_NM']).isNotEmpty) '관리기관: ${pick(r['INST_NM'])}',
      if (pick(r['INST_TELNO']).isNotEmpty) '전화번호: ${pick(r['INST_TELNO'])}',
      if (pick(r['ASG_DATE']).isNotEmpty) '조성년월: ${pick(r['ASG_DATE'])}',
      if (pick(r['REFDATE']).isNotEmpty) '기준일자: ${pick(r['REFDATE'])}',
    ];

    return lines.join('\n');
  }
}

class _CurrentCountText extends StatelessWidget {
  final MapVm vm;

  const _CurrentCountText({
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final items = vm.visibleItems;

    final toiletCnt = items.where((e) => e.type == PoiType.toilet).length;
    final parkCnt = items.where((e) => e.type == PoiType.park).length;
    final erCnt = items.where((e) => e.type == PoiType.er).length;
    final safeRouteCnt =
        items.where((e) => e.type == PoiType.safeRoute).length;

    final parts = <String>[];

    if (vm.showToilet) {
      parts.add('화장실 ${toiletCnt}개');
    }

    if (vm.showPark) {
      parts.add('공원 ${parkCnt}개');
    }

    if (vm.showEr) {
      parts.add('응급실 ${erCnt}개');
    }

    if (vm.showSafeRoute) {
      parts.add('안심귀갓길 ${safeRouteCnt}개');
    }

    final text = parts.isEmpty
        ? '현재 표시 : 없음 (반경 ${vm.radiusLabel(vm.radiusKm)})'
        : '현재 표시 : ${parts.join(', ')} (반경 ${vm.radiusLabel(vm.radiusKm)})';

    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}