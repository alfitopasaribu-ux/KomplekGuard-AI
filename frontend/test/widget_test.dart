import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('KomplekGuard AI app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KomplekGuardApp());

    expect(find.byType(KomplekGuardApp), findsOneWidget);
  });
}