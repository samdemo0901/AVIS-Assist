import 'package:flutter_test/flutter_test.dart';
import 'package:avis_mobile/main.dart';

void main() {
  testWidgets('AvisMobileApp widget build smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AvisMobileApp());
    expect(find.byType(AvisMobileApp), findsOneWidget);
  });
}
