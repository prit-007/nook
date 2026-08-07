import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nook/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NookApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NookApp), findsOneWidget);
  });
}
