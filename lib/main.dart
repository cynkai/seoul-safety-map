// Keep the Material import available on the supported Flutter 3.38 releases.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'core/seoul_api.dart';
import 'features/map/map_page.dart';
import 'features/map/map_vm.dart';

void main() {
  final api = SeoulOpenApi();
  final vm = MapVm(api: api);

  runApp(MyApp(vm: vm));
}

class MyApp extends StatelessWidget {
  final MapVm vm;
  const MyApp({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '서울 안전시설 지도',
      theme: ThemeData(useMaterial3: true),
      home: MapPage(vm: vm),
    );
  }
}
