import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/safety_quick_guide.dart';
import 'package:frontend/widgets/safety_response_text.dart';

void main() {
  testWidgets('bold Markdown is formatted without showing asterisks',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SafetyResponseText(
          '1. **Jauhi bahaya** – pergi ke tempat aman.\n'
          '2. **Minta bantuan** dari petugas.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    ));

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('Jauhi bahaya'), findsOneWidget);
    expect(find.textContaining('Minta bantuan'), findsOneWidget);
  });

  test('panduan keselamatan dasar tersedia tanpa akses jaringan', () {
    expect(SafetyQuickGuide.guides.length, greaterThanOrEqualTo(5));
    for (final guide in SafetyQuickGuide.guides) {
      expect(guide.title.isNotEmpty, isTrue);
      expect(guide.steps.length, greaterThanOrEqualTo(3));
    }
  });
}
