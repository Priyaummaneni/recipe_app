
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final provider = RecipeProvider(prefs);
        provider.loadRecipes('chicken');
        return provider;
      },
      child: const RecipeApp(),
    ),
  );
}

// -------------------- RECIPE MODEL --------------------

class Recipe {
  final String id;
  final String name;
  final String time;
  final String ingredients;
  final String instructions;
  final String emoji;
  final String imageUrl;

  const Recipe({
    required this.id,
    required this.name,
    required this.time,
    required this.ingredients,
    required this.instructions,
    this.emoji = '🍽️',
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'time': time,
      'ingredients': ingredients,
      'instructions': instructions,
      'emoji': emoji,
      'imageUrl': imageUrl,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      time: map['time'] ?? 'Not specified',
      ingredients: map['ingredients'] ?? '',
      instructions: map['instructions'] ?? '',
      emoji: map['emoji'] ?? '🍽️',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  factory Recipe.fromMealApi(Map<String, dynamic> meal) {
    final ingredients = <String>[];

    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i']?.toString().trim() ?? '';
      final measure = meal['strMeasure$i']?.toString().trim() ?? '';

      if (ingredient.isNotEmpty) {
        ingredients.add(
          measure.isEmpty ? ingredient : '$measure $ingredient',
        );
      }
    }

    return Recipe(
      id: meal['idMeal']?.toString() ?? '',
      name: meal['strMeal']?.toString() ?? 'Untitled Recipe',
      time: 'See instructions',
      ingredients: ingredients.join('\n'),
      instructions:
          meal['strInstructions']?.toString() ?? 'No instructions available.',
      emoji: '🍲',
      imageUrl: meal['strMealThumb']?.toString() ?? '',
    );
  }
}

// -------------------- PROVIDER / APP DATA --------------------

class RecipeProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  RecipeProvider(this.prefs) {
    final savedRecipes = prefs.getString('custom_recipes');

    if (savedRecipes != null) {
      try {
        final decoded = jsonDecode(savedRecipes) as List;
        _customRecipes = decoded
            .map((item) => Recipe.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      } catch (_) {
        _customRecipes = [];
      }
    }

    _favoriteIds = prefs.getStringList('favorite_ids')?.toSet() ?? {};
  }

  List<Recipe> _apiRecipes = [];
  List<Recipe> _customRecipes = [];
  Set<String> _favoriteIds = {};

  bool isLoading = false;
  String? errorMessage;

  List<Recipe> get allRecipes => [
        ..._apiRecipes,
        ..._customRecipes,
      ];

  List<Recipe> get favoriteRecipes =>
      allRecipes.where((recipe) => _favoriteIds.contains(recipe.id)).toList();

  bool isFavorite(Recipe recipe) => _favoriteIds.contains(recipe.id);

  Future<void> loadRecipes(String search) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://www.themealdb.com/api/json/v1/1/search.php?s=${Uri.encodeComponent(search)}',
      );

      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        throw Exception('Could not load recipes. Please try again.');
      }

      final data = jsonDecode(response.body);
      final meals = data['meals'] as List?;

      _apiRecipes = meals == null
          ? []
          : meals
              .map((meal) => Recipe.fromMealApi(
                    Map<String, dynamic>.from(meal),
                  ))
              .toList();
    } catch (e) {
      errorMessage = 'Unable to connect. Check your internet and try again.';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> addRecipe(Recipe recipe) async {
    _customRecipes.add(recipe);
    await prefs.setString(
      'custom_recipes',
      jsonEncode(_customRecipes.map((r) => r.toMap()).toList()),
    );
    notifyListeners();
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    if (_favoriteIds.contains(recipe.id)) {
      _favoriteIds.remove(recipe.id);
    } else {
      _favoriteIds.add(recipe.id);
    }

    await prefs.setStringList('favorite_ids', _favoriteIds.toList());
    notifyListeners();
  }
}

// -------------------- APP THEME --------------------

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recipe App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// -------------------- HOME AND FAVOURITES --------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();

    final recipes = selectedIndex == 0
        ? provider.allRecipes
        : provider.favoriteRecipes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍳 Recipe App'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              selectedIndex == 0
                  ? 'Discover Delicious Recipes!'
                  : 'Your Favourite Recipes ❤️',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    context.read<RecipeProvider>().loadRecipes(value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search recipes, e.g. chicken...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      final value = searchController.text.trim();
                      if (value.isNotEmpty) {
                        context.read<RecipeProvider>().loadRecipes(value);
                      }
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

          if (selectedIndex == 0 && provider.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (selectedIndex == 0 && provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton.icon(
                    onPressed: () => provider.loadRecipes(
                      searchController.text.trim().isEmpty
                          ? 'chicken'
                          : searchController.text.trim(),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),

          Expanded(
            child: recipes.isEmpty
                ? Center(
                    child: Text(
                      selectedIndex == 1
                          ? 'No favourites yet.\nTap the heart on a recipe!'
                          : provider.isLoading
                              ? 'Loading recipes...'
                              : 'No recipes found. Try another search.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: recipe.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    recipe.imageUrl,
                                    width: 65,
                                    height: 65,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.restaurant, size: 35),
                                  ),
                                )
                              : Text(
                                  recipe.emoji,
                                  style: const TextStyle(fontSize: 35),
                                ),
                          title: Text(
                            recipe.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text('Cooking time: ${recipe.time}'),
                          trailing: IconButton(
                            icon: Icon(
                              provider.isFavorite(recipe)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                provider.toggleFavorite(recipe),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailsScreen(recipe: recipe),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddRecipeScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.deepOrange,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
        ],
      ),
    );
  }
}

// -------------------- RECIPE DETAILS --------------------

class RecipeDetailsScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailsScreen({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final ingredients = recipe.ingredients
        .split('\n')
        .where((item) => item.trim().isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Details'),
        actions: [
          IconButton(
            icon: Icon(
              provider.isFavorite(recipe)
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: () => provider.toggleFavorite(recipe),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  recipe.imageUrl,
                  width: double.infinity,
                  height: 210,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 100,
                    child: Center(child: Icon(Icons.restaurant, size: 50)),
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  recipe.emoji,
                  style: const TextStyle(fontSize: 75),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              recipe.name,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('⏱ Cooking time: ${recipe.time}'),
            const SizedBox(height: 22),
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (ingredients.isEmpty)
              const Text('No ingredients listed.')
            else
              ...ingredients.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 22),
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.instructions,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- ADD RECIPE FORM --------------------

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final timeController = TextEditingController();
  final ingredientsController = TextEditingController();
  final instructionsController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    timeController.dispose();
    ingredientsController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  Future<void> saveRecipe() async {
    if (!formKey.currentState!.validate()) return;

    final recipe = Recipe(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text.trim(),
      time: '${timeController.text.trim()} minutes',
      ingredients: ingredientsController.text.trim(),
      instructions: instructionsController.text.trim(),
      emoji: '🍽️',
    );

    await context.read<RecipeProvider>().addRecipe(recipe);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipe added successfully!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Recipe')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Share Your Recipe 🍲',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Please enter a recipe name'
                      : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: timeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cooking Time (minutes)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final time = int.tryParse(value ?? '');
                if (time == null || time <= 0) {
                  return 'Enter a valid time greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: ingredientsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ingredients (one per line)',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Please enter ingredients'
                      : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: instructionsController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Cooking Instructions',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Please enter instructions'
                      : null,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: saveRecipe,
              icon: const Icon(Icons.save),
              label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Save Recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
