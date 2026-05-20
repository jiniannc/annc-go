import 'package:annc_go/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows setup screen on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AnncGoApp()),
    );

    expect(find.text('Flight Setup'), findsOneWidget);
    expect(find.text('Save Setup'), findsOneWidget);
  });
}
