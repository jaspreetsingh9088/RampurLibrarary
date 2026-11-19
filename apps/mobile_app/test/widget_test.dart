import 'package:flutter_test/flutter_test.dart';
import 'package:rampur_library/screens/not_configured_screen.dart';

void main() {
  testWidgets('shows setup screen when Firebase is not configured', (tester) async {
    await tester.pumpWidget(const NotConfiguredApp());
    expect(find.text('Almost there!'), findsOneWidget);
  });
}
