import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tirupati_traders/main.dart';

void main() {
  testWidgets('Role selection screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TirupatiApp()));

    expect(find.text('Tirupati Traders'), findsOneWidget);
    expect(find.text('I am a Customer'), findsOneWidget);
    expect(find.text('I am Staff / Admin'), findsOneWidget);
  });
}
