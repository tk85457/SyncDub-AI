import 'package:flutter_test/flutter_test.dart';
import 'package:syncdub_app/main.dart';

void main() {
  testWidgets('SyncDub App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SyncDubApp());
    await tester.pumpAndSettle();

    // Verify app brand is rendered
    expect(find.text('SyncDub'), findsOneWidget);
  });
}
