import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skincare_app/main.dart';

void main() {
  testWidgets('SkinCare app boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkinCareApp()));
    await tester.pump();

    expect(find.text('SkinCare'), findsOneWidget);
  });
}
