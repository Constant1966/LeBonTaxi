import 'package:flutter_test/flutter_test.dart';
import 'package:drivers_app/main.dart';

void main() {
  testWidgets('MyApp se lance correctement', (WidgetTester tester) async {
    // Vérifier que l'app se construit sans erreur
    await tester.pumpWidget(const MyApp());

    // Vérifier que le widget existe
    expect(find.byType(MyApp), findsOneWidget);
  });
}
