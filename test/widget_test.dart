import 'package:flutter_test/flutter_test.dart';
import 'package:boss_game/main.dart';

void main() {
  testWidgets('App launches home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BossGameApp());
    expect(find.text('Босс & Команда'), findsOneWidget);
    expect(find.text('Я БОСС'), findsOneWidget);
    expect(find.text('Я ПОДЧИНЁННЫЙ'), findsOneWidget);
  });
}
