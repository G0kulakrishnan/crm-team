import 'package:flutter_test/flutter_test.dart';
import 'package:crm_call_logger/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const CrmCallLoggerApp());
    await tester.pump();
    expect(find.byType(CrmCallLoggerApp), findsOneWidget);
  });
}
