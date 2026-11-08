
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recipe_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Recipe app displays the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => RecipeProvider(prefs),
        child: const RecipeApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Discover Delicious Recipes!'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
  });
}
