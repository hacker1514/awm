import 'package:flutter_test/flutter_test.dart';
import 'package:awy/main.dart';

void main() {
  testWidgets('AWM App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AWMApp());
    expect(find.text('AWM'), findsOneWidget);
  });
}
