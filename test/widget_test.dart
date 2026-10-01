import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:we_two/app/app.dart';

void main() {
  testWidgets('boots the We Two shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WeTwoApp()));

    expect(find.textContaining('We Two'), findsOneWidget);
  });
}
