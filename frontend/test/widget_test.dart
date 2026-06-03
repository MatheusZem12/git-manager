import 'package:flutter_test/flutter_test.dart';
import 'package:git_manager_ui/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GitManagerApp());
    expect(find.text('Git Manager'), findsOneWidget);
  });
}
