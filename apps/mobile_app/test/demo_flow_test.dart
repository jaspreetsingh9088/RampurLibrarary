import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rampur_library/app.dart';
import 'package:rampur_library/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('demo mode: OTP login leads to profile completion and home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'onboardingSeen': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs), isDemoProvider.overrideWithValue(true)],
      child: const RampurLibraryApp(),
    ));
    await settle(tester);

    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await settle(tester);
    expect(find.text('Enter the code'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await settle(tester, 3);
    expect(find.text('Complete your profile'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name *'), 'Jaspreet Singh');
    await tester.scrollUntilVisible(find.text('Continue'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Continue'), warnIfMissed: true);
    await settle(tester, 3);
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    debugPrint('MEMBER: name="${c.read(memberProvider).value?.name}" loading=${c.read(memberProvider).isLoading} '
        'loc=${c.read(routerProvider).routerDelegate.currentConfiguration.uri}');
    debugPrint('SCREEN TEXTS: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText()).take(40).join(' | ')}');
    expect(find.text('Jaspreet'), findsOneWidget); // greeting on home
    expect(find.text('Currently reading'), findsOneWidget);
  });
}
