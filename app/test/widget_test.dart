import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skincare_app/main.dart';

void main() {
  testWidgets('SkinCare app boots to the splash screen, then onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: SkinCareApp()));
    await tester.pump();

    expect(find.text('SkinCare'), findsOneWidget);

    // Splash holds ~2.2s, then a first-time visitor lands on onboarding.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
  });
}
