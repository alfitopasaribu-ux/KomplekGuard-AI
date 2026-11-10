import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/theme/nexus_guard_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const v3CaptureEnabled = bool.fromEnvironment('CAPTURE_UI');
const v3TestUser = <String, dynamic>{
  'id': 'resident-test',
  'name': 'Nadia Warga',
  'email': 'nadia@example.test',
  'phone': '081200000000',
  'address': 'Alamat khusus pengujian',
  'role': 'WARGA',
};
const v3TestToken = 'test-session-token';
final _boundaryKey = GlobalKey();

void v3SeedSession({Map<String, dynamic>? user, String token = v3TestToken}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppConstants.tokenKey: token,
    AppConstants.userKey: jsonEncode(user ?? v3TestUser),
  });
}

http.Response v3Json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> v3Frames(WidgetTester tester, {int count = 8}) async {
  await tester.pump();
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> v3Pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: NexusGuard.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  ));
  await v3Frames(tester);
}

Future<void> v3WithApi(
  WidgetTester tester,
  Future<void> Function(List<http.Request> requests) body, {
  required FutureOr<http.Response> Function(http.Request request) respond,
}) async {
  final requests = <http.Request>[];
  await http.runWithClient<Future<void>>(() async {
    try {
      await body(requests);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, () => MockClient((request) async {
    requests.add(request);
    return await respond(request);
  }));
}

Future<void> v3Tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await v3Frames(tester);
}

Future<void> v3LoadFonts() async {
  if (!v3CaptureEnabled) return;
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'D:/SDK/flutter';
  final fonts = FontLoader('Roboto');
  for (final font in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    fonts.addFont(() async {
      final bytes = await File('$sdk/bin/cache/artifacts/material_fonts/$font')
          .readAsBytes();
      return ByteData.sublistView(bytes);
    }());
  }
  await fonts.load();
  final icons = FontLoader('MaterialIcons');
  icons.addFont(() async {
    final bytes = await File(
            '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
        .readAsBytes();
    return ByteData.sublistView(bytes);
  }());
  await icons.load();
}

Future<void> v3Capture(WidgetTester tester, String name) async {
  if (!v3CaptureEnabled) return;
  await v3Frames(tester);
  await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const directory = String.fromEnvironment('UI_CAPTURE_DIR',
        defaultValue: 'C:/komplekguard-ai/.cache/flutter-v3-stage2');
    final output = File('$directory/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
