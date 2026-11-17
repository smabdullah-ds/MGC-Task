import 'package:bazaar_sort/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots with fake services', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BazaarSortApp()));
    await tester.pumpAndSettle();
    expect(find.text('Bazaar Sort'), findsWidgets);
  });
}
