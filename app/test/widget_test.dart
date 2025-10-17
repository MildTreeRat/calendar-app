import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:app/main.dart' as app;


void main() {
testWidgets('app boots and increments counter', (tester) async {
app.main();
await tester.pumpAndSettle();
expect(find.textContaining('taps='), findsOneWidget);
await tester.tap(find.byType(FloatingActionButton));
await tester.pump();
expect(find.text('Hello! taps=1'), findsOneWidget);
});
}
