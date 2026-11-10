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
import 'package:frontend/main.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:frontend/screens/auth/register_screen.dart';
import 'package:frontend/screens/dashboard/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureUi = bool.fromEnvironment('CAPTURE_UI');
const _captureDirectory = String.fromEnvironment(
  'UI_CAPTURE_DIR',
  defaultValue: 'C:/komplekguard-ai/.cache/flutter-v3',
);
const _user = <String, dynamic>{
  'id': 'test-warga',
  'name': 'Nadia Warga',
  'email': 'nadia@example.test',
  'role': 'WARGA',
};
const _token = 'test-session-token';
final _captureBoundary = GlobalKey();

Map<String, Object> _session() => {
      AppConstants.tokenKey: _token,
      AppConstants.userKey: jsonEncode(_user),
    };

Map<String, dynamic> _alert({String title = 'Pohon tumbang di gerbang'}) => {
      'id': 'test-alert',
      'title': title,
      'description': 'Dahan menutup sebagian akses masuk lingkungan.',
      'status': 'DIPROSES',
      'latitude': -8.65,
      'longitude': 115.2167,
      'createdAt': '2026-01-02T03:04:00.000Z',
      'user': {'id': 'reporter', 'name': 'Budi Pelapor'},
      'category': {'name': 'Pohon Tumbang', 'type': 'BENCANA'},
      'responses': [
        {'id': 'response-1', 'responseStatus': 'MENUJU_LOKASI'},
        {'id': 'response-2', 'responseStatus': 'MEMBANTU'},
      ],
      'riskLevel': 'SEDANG',
      'aiSummaries': [
        {'riskLevel': 'TINGGI', 'summary': 'Hindari area pohon tumbang.'},
      ],
    };

http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _alerts([List<dynamic> alerts = const []]) =>
    _json({'success': true, 'data': alerts});

http.Response _authSuccess() => _json({
      'success': true,
      'data': {'token': _token, 'user': _user},
    });

Future<void> _frames(WidgetTester tester) async {
  // Storage/HTTP futures may start route transitions after the first frame.
  // Advance several bounded frames so outgoing routes finish their animation;
  // a single large jump can occur before that transition has even started.
  // Avoid pumpAndSettle because loading indicators and dashboard polls persist.
  await tester.pump();
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _withApi(
  WidgetTester tester,
  Future<void> Function(List<http.Request> requests) body, {
  FutureOr<http.Response> Function(http.Request request)? respond,
}) async {
  final requests = <http.Request>[];
  await http.runWithClient<Future<void>>(
    () async {
      try {
        await body(requests);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
    // The top-level HTTP helpers close their client after every request.
    () => MockClient((request) async {
      requests.add(request);
      if (respond != null) return await respond(request);
      if (request.method == 'GET' && request.url.path == '/api/alerts/active') {
        return _alerts();
      }
      throw StateError(
          'Unexpected HTTP request: ${request.method} ${request.url}');
    }),
  );
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _screen(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _captureBoundary,
    child: MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: NexusGuard.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: screen,
    ),
  ));
  await _frames(tester);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await _frames(tester);
}

Future<void> _loginFields(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('login_email')), ' nadia@example.test ');
  await tester.enterText(
      find.byKey(const ValueKey('login_password')), 'password-test');
}

Future<void> _registerFields(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const ValueKey('register_name')), ' Nadia Warga ');
  await tester.enterText(
      find.byKey(const ValueKey('register_email')), ' nadia@example.test ');
  await tester.enterText(
      find.byKey(const ValueKey('register_phone')), ' 081234000000 ');
  await tester.enterText(
      find.byKey(const ValueKey('register_password')), 'password-test');
}

bool _fieldHasError(WidgetTester tester, String key) =>
    tester.state<FormFieldState<String>>(find.byKey(ValueKey(key))).hasError;

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find
        .descendant(
          of: find.byKey(ValueKey(key)),
          matching:
              find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          matchRoot: true,
        )
        .first);

Future<void> _expectSession() async {
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.getString(AppConstants.tokenKey), _token);
  expect(jsonDecode(prefs.getString(AppConstants.userKey)!), _user);
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureUi) return;
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    final position = tester.state<ScrollableState>(scrollables.first).position;
    position.jumpTo(position.minScrollExtent);
  }
  await _frames(tester);
  await tester.runAsync(() async {
    final boundary = _captureBoundary.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('$_captureDirectory/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List(), flush: true);
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() async {
    if (!_captureUi) return;
    // Real glyphs for optional local screenshots, independent of production.
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'D:/SDK/flutter';
    // Ahem is the widget-test fallback for explicit styles without a family.
    // Alias it to real glyphs only for screenshots, leaving ordinary tests and
    // all production typography unchanged.
    for (final family in ['Roboto', 'Ahem']) {
      final loader = FontLoader(family);
      for (final font in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf'
      ]) {
        loader.addFont(() async {
          final bytes =
              await File('$sdk/bin/cache/artifacts/material_fonts/$font')
                  .readAsBytes();
          return ByteData.sublistView(bytes);
        }());
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(() async {
      final bytes = await File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
          .readAsBytes();
      return ByteData.sublistView(bytes);
    }());
    await icons.load();
  });

  testWidgets('startup without a session reaches login without an API request',
      (tester) async {
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await tester.pumpWidget(const KomplekGuardApp());
      await tester.pump(const Duration(seconds: 2));
      await _frames(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('startup restores saved user and sends the saved Bearer token',
      (tester) async {
    SharedPreferences.setMockInitialValues(_session());
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await tester.pumpWidget(const KomplekGuardApp());
      await tester.pump(const Duration(seconds: 2));
      await _frames(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.textContaining('Nadia'), findsWidgets);
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.toString(), '${AppConstants.baseUrl}/alerts/active');
      expect(request.headers['authorization'], 'Bearer $_token');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('login validates required fields and email before sending HTTP',
      (tester) async {
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const LoginScreen());
      await _tap(tester, 'login_submit');
      expect(_fieldHasError(tester, 'login_email'), isTrue);
      expect(_fieldHasError(tester, 'login_password'), isTrue);
      await tester.enterText(
          find.byKey(const ValueKey('login_email')), 'bukan-email');
      await tester.enterText(
          find.byKey(const ValueKey('login_password')), 'password-test');
      await _tap(tester, 'login_submit');
      expect(_fieldHasError(tester, 'login_email'), isTrue);
      expect(requests, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.tokenKey), isNull);
    });
  });

  testWidgets('registration validates name email and password locally',
      (tester) async {
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const RegisterScreen());
      await _tap(tester, 'register_submit');
      for (final key in [
        'register_name',
        'register_email',
        'register_password'
      ]) {
        expect(_fieldHasError(tester, key), isTrue, reason: key);
      }
      expect(_fieldHasError(tester, 'register_phone'), isFalse);
      expect(requests, isEmpty);
    });
  });

  for (final registration in [false, true]) {
    testWidgets(
        '${registration ? 'registration' : 'login'} displays backend rejection without starting a session',
        (tester) async {
      final prefix = registration ? 'register' : 'login';
      final message =
          registration ? 'Email sudah terdaftar' : 'Email atau password salah';
      _viewport(tester, const Size(390, 844));
      await _withApi(tester, (requests) async {
        await _screen(tester,
            registration ? const RegisterScreen() : const LoginScreen());
        if (registration) {
          await _registerFields(tester);
        } else {
          await _loginFields(tester);
        }
        await _tap(tester, '${prefix}_submit');
        expect(find.byKey(ValueKey('${prefix}_error')), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.byType(DashboardScreen), findsNothing);
        expect(requests, hasLength(1));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppConstants.tokenKey), isNull);
        expect(prefs.getString(AppConstants.userKey), isNull);
        expect(_button(tester, '${prefix}_submit').onPressed, isNotNull);
      },
          respond: (_) =>
              _json({'success': false, 'message': message}, status: 401));
    });
  }

  testWidgets('login disables input and duplicate submissions while pending',
      (tester) async {
    final pending = Completer<http.Response>();
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const LoginScreen());
      await _loginFields(tester);
      await _tap(tester, 'login_submit');
      expect(requests, hasLength(1));
      expect(_button(tester, 'login_submit').onPressed, isNull);
      expect(
          tester
              .widget<TextFormField>(find.byKey(const ValueKey('login_email')))
              .enabled,
          isFalse);
      expect(
          tester
              .widget<TextFormField>(
                  find.byKey(const ValueKey('login_password')))
              .enabled,
          isFalse);
      pending
          .complete(_json({'success': false, 'message': 'Silakan coba lagi'}));
      await _frames(tester);
      expect(_button(tester, 'login_submit').onPressed, isNotNull);
      expect(find.text('Silakan coba lagi'), findsOneWidget);
    }, respond: (_) => pending.future);
  });

  for (final registration in [false, true]) {
    testWidgets(
        '${registration ? 'registration' : 'login'} preserves API payload session and dashboard navigation',
        (tester) async {
      final prefix = registration ? 'register' : 'login';
      _viewport(tester, const Size(390, 844));
      await _withApi(tester, (requests) async {
        await _screen(tester,
            registration ? const RegisterScreen() : const LoginScreen());
        if (registration) {
          await _registerFields(tester);
        } else {
          await _loginFields(tester);
        }
        await _tap(tester, '${prefix}_submit');
        final authRequest = requests.first;
        expect(authRequest.method, 'POST');
        expect(
            authRequest.url.toString(), '${AppConstants.baseUrl}/auth/$prefix');
        expect(
            authRequest.headers['content-type'], contains('application/json'));
        expect(jsonDecode(authRequest.body), {
          if (registration) 'name': 'Nadia Warga',
          'email': 'nadia@example.test',
          'password': 'password-test',
          if (registration) 'phone': '081234000000',
        });
        await _expectSession();
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(RegisterScreen), findsNothing);
        expect(requests.last.url.path, '/api/alerts/active');
        expect(requests.last.headers['authorization'], 'Bearer $_token');
        expect(tester.takeException(), isNull);
      },
          respond: (request) => request.url.path.startsWith('/api/auth/')
              ? _authSuccess()
              : _alerts());
    });
  }

  testWidgets(
      'registration link opens the form and returns to the original login',
      (tester) async {
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const LoginScreen());
      await _tap(tester, 'login_register');
      expect(find.byType(RegisterScreen), findsOneWidget);
      await _tap(tester, 'register_login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
      expect(requests, isEmpty);
    });
  });

  testWidgets('dashboard distinguishes loading from a confirmed empty list',
      (tester) async {
    SharedPreferences.setMockInitialValues(_session());
    final pending = Completer<http.Response>();
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const DashboardScreen());
      expect(find.byKey(const ValueKey('dashboard-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-empty')), findsNothing);
      pending.complete(_alerts());
      await _frames(tester);
      expect(find.byKey(const ValueKey('dashboard-loading')), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-empty')), findsOneWidget);
      expect(requests, hasLength(1));
    }, respond: (_) => pending.future);
  });

  testWidgets('dashboard error offers retry instead of declaring an empty area',
      (tester) async {
    SharedPreferences.setMockInitialValues(_session());
    var attempts = 0;
    _viewport(tester, const Size(390, 844));
    await _withApi(tester, (requests) async {
      await _screen(tester, const DashboardScreen());
      expect(find.byKey(const ValueKey('dashboard-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-empty')), findsNothing);
      await _tap(tester, 'dashboard-retry');
      expect(find.byKey(const ValueKey('dashboard-error')), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-empty')), findsOneWidget);
      expect(requests, hasLength(2));
      expect(tester.takeException(), isNull);
    }, respond: (_) {
      attempts++;
      return attempts == 1
          ? _json({'success': false, 'message': 'Koneksi laporan terputus'},
              status: 503)
          : _alerts();
    });
  });

  testWidgets(
      'dashboard renders server incidents and refreshes through its poll',
      (tester) async {
    SharedPreferences.setMockInitialValues(_session());
    var attempts = 0;
    _viewport(tester, const Size(1440, 1000));
    await _withApi(tester, (requests) async {
      await _screen(tester, const DashboardScreen());
      expect(find.textContaining('Nadia'), findsWidgets);
      expect(find.text('Pohon tumbang di gerbang'), findsWidgets);
      expect(find.textContaining('Budi Pelapor'), findsWidgets);
      expect(find.text('Tinggi'), findsWidgets);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('dashboard-active-count')))
              .data,
          '1');
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('dashboard-waiting-count')))
              .data,
          '0');
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('dashboard-response-count')))
              .data,
          '2');
      expect(find.byKey(const ValueKey('dashboard-empty')), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await _frames(tester);
      expect(requests, hasLength(2));
      expect(find.text('Laporan sudah diperbarui'), findsWidgets);
      expect(find.text('Pohon tumbang di gerbang'), findsNothing);
      expect(tester.takeException(), isNull);
    }, respond: (_) {
      attempts++;
      return _alerts([
        _alert(
            title: attempts == 1
                ? 'Pohon tumbang di gerbang'
                : 'Laporan sudah diperbarui')
      ]);
    });
  });

  testWidgets(
      'dashboard preserves feature navigation and logout clears session',
      (tester) async {
    SharedPreferences.setMockInitialValues(_session());
    _viewport(tester, const Size(1440, 1000));
    await _withApi(tester, (requests) async {
      await _screen(tester, const DashboardScreen());
      for (final key in [
        'dashboard-create-alert',
        'dashboard-open-map',
        'dashboard-open-assistant',
        'dashboard-open-contacts',
        'dashboard-all-alerts',
        'dashboard-nav-profile',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      await _tap(tester, 'dashboard-account-menu');
      await tester.tap(find.text('Keluar'));
      await _frames(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.tokenKey), isNull);
      expect(prefs.getString(AppConstants.userKey), isNull);
      expect(tester.takeException(), isNull);
    });
  });

  final viewports = <({String name, Size size, double scale})>[
    (name: 'small-mobile', size: const Size(320, 740), scale: 1),
    (name: 'mobile', size: const Size(390, 844), scale: 1),
    (name: 'desktop', size: const Size(1440, 1000), scale: 1),
    (name: 'large-text', size: const Size(390, 844), scale: 1.4),
  ];
  for (final viewport in viewports) {
    testWidgets('auth and dashboard remain usable on ${viewport.name}',
        (tester) async {
      _viewport(tester, viewport.size);
      await _withApi(tester, (requests) async {
        await _screen(tester, const LoginScreen(), textScale: viewport.scale);
        await tester.ensureVisible(find.byKey(const ValueKey('login_submit')));
        expect(find.byKey(const ValueKey('login_email')), findsOneWidget);
        expect(_button(tester, 'login_submit').onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'login-${viewport.name}');

        await _screen(tester, const RegisterScreen(),
            textScale: viewport.scale);
        await tester
            .ensureVisible(find.byKey(const ValueKey('register_submit')));
        expect(find.byKey(const ValueKey('register_phone')), findsOneWidget);
        expect(_button(tester, 'register_submit').onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'register-${viewport.name}');

        SharedPreferences.setMockInitialValues(_session());
        await _screen(tester, const DashboardScreen(),
            textScale: viewport.scale);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text('Pohon tumbang di gerbang'), findsWidgets);
        expect(find.byKey(const ValueKey('dashboard-error')), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'dashboard-${viewport.name}');
      }, respond: (_) => _alerts([_alert()]));
    });
  }
}
