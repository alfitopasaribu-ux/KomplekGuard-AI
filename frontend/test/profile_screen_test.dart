import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/screens/profile/profile_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/v3_test_support.dart';

Map<String, dynamic> _profile({String name = 'Nadia Warga', String? image}) => {
  'id': v3TestUser['id'],
  'name': name,
  'email': 'nadia@example.test',
  'phone': '081200000000',
  'address': 'Alamat dari server untuk pengujian',
  'image': image,
};

http.Response _success({String name = 'Nadia Warga', String? image}) =>
    v3Json({'success': true, 'data': _profile(name: name, image: image)});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(v3SeedSession);
  setUpAll(v3LoadFonts);

  testWidgets('profile reads the existing endpoint and keeps the cached role', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      expect(requests.single.method, 'GET');
      expect(requests.single.url.toString(), '${AppConstants.baseUrl}/users/profile');
      expect(requests.single.headers['authorization'], 'Bearer $v3TestToken');
      expect(find.text('Warga'), findsOneWidget);
      expect(find.text('Alamat dari server untuk pengujian'), findsWidgets);
      expect(find.byKey(const ValueKey('profile-load-error')), findsNothing);
      expect(tester.takeException(), isNull);
    }, respond: (_) => _success());
  });

  testWidgets('profile reports failure and preserves cached fields instead of blanking them', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      expect(find.byKey(const ValueKey('profile-load-error')), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byKey(const ValueKey('profile-name')));
      expect(field.controller!.text, v3TestUser['name']);
      expect(find.byKey(const ValueKey('profile-identity')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, respond: (_) => v3Json({'success': false, 'message': 'Tidak tersedia'}, status: 503));
  });

  testWidgets('profile with no cached user exposes retry and cannot save blank data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var attempts = 0;
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      expect(find.byKey(const ValueKey('profile-load-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-name')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('profile-save-top'))).onPressed, isNull);
      await v3Tap(tester, 'profile-retry');
      expect(find.byKey(const ValueKey('profile-load-error')), findsNothing);
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    }, respond: (_) {
      attempts++;
      return attempts == 1 ? v3Json({'success': false}, status: 503) : _success();
    });
  });

  testWidgets('empty profile name is rejected without writing to the server', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      await tester.enterText(find.byKey(const ValueKey('profile-name')), '   ');
      await v3Tap(tester, 'profile-save');
      expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    }, respond: (_) => _success());
  });

  testWidgets('profile saves original payload and merges the confirmed user into the same session', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      await tester.enterText(find.byKey(const ValueKey('profile-name')), ' Nadia Baru ');
      await tester.enterText(find.byKey(const ValueKey('profile-phone')), ' 081211111111 ');
      await tester.enterText(find.byKey(const ValueKey('profile-address')), ' Alamat baru ');
      await v3Tap(tester, 'profile-save');
      final request = requests.singleWhere((r) => r.method == 'PUT');
      expect(request.url.toString(), '${AppConstants.baseUrl}/users/profile');
      expect(request.headers['authorization'], 'Bearer $v3TestToken');
      expect(jsonDecode(request.body), {
        'name': 'Nadia Baru', 'phone': '081211111111', 'address': 'Alamat baru',
      });
      expect(find.byKey(const ValueKey('profile-saved')), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppConstants.tokenKey), v3TestToken);
      final user = jsonDecode(preferences.getString(AppConstants.userKey)!);
      expect(user['name'], 'Nadia Dikonfirmasi Server');
      expect(user['role'], 'WARGA');
      expect(tester.takeException(), isNull);
    }, respond: (request) => request.method == 'PUT'
        ? _success(name: 'Nadia Dikonfirmasi Server') : _success());
  });

  testWidgets('rejected profile write never claims success or changes the local session', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Nama belum tersimpan');
      await v3Tap(tester, 'profile-save');
      expect(find.byKey(const ValueKey('profile-save-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-saved')), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      final user = jsonDecode(preferences.getString(AppConstants.userKey)!);
      expect(user['name'], v3TestUser['name']);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('profile-save'))).onPressed, isNotNull);
    }, respond: (request) => request.method == 'PUT'
        ? v3Json({'success': false, 'message': 'Perubahan ditolak'}, status: 403) : _success());
  });

  testWidgets('profile prevents duplicate writes while save is pending', (tester) async {
    final pending = Completer<http.Response>();
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      await v3Tap(tester, 'profile-save');
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('profile-save'))).onPressed, isNull);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('profile-save-top'))).onPressed, isNull);
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
      pending.complete(_success());
      await v3Frames(tester);
      expect(find.byKey(const ValueKey('profile-saved')), findsOneWidget);
    }, respond: (request) => request.method == 'PUT' ? pending.future : _success());
  });

  testWidgets('photo controls retain gallery and both camera options', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      await v3Tap(tester, 'profile-change-photo');
      for (final key in ['profile-photo-gallery', 'profile-photo-front', 'profile-photo-rear']) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
    }, respond: (_) => _success());
  });

  testWidgets('malformed avatar data never breaks the profile form', (tester) async {
    await v3WithApi(tester, (requests) async {
      await v3Pump(tester, const ProfileScreen());
      expect(find.byKey(const ValueKey('profile-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, respond: (_) => _success(image: 'data:image/png;base64,not-valid-base64'));
  });

  for (final viewport in [
    (name: 'small-mobile', size: const Size(320, 740), scale: 1.0),
    (name: 'mobile', size: const Size(390, 844), scale: 1.0),
    (name: 'desktop', size: const Size(1440, 1000), scale: 1.0),
    (name: 'large-text', size: const Size(390, 844), scale: 1.4),
  ]) {
    testWidgets('profile remains usable on ${viewport.name}', (tester) async {
      await v3WithApi(tester, (requests) async {
        await v3Pump(tester, const ProfileScreen(), size: viewport.size, textScale: viewport.scale);
        await tester.ensureVisible(find.byKey(const ValueKey('profile-save')));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byKey(const ValueKey('profile-scroll')), const Offset(0, 2000));
        await v3Frames(tester);
        await v3Capture(tester, 'profile-${viewport.name}');
      }, respond: (_) => _success());
    });
  }
}
