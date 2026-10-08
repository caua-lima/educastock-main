import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/recipes_remote_datasource.dart';
import '../../domain/entities/stock_recipe.dart';

final recipesDatasourceProvider = Provider<RecipesRemoteDatasource>(
  (_) => RecipesRemoteDatasource(),
);

final recipesProvider = StreamProvider<List<StockRecipe>>((ref) {
  return ref.watch(recipesDatasourceProvider).watchRecipes();
});

class RecipesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> ensureSeed() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(recipesDatasourceProvider).ensureSeedTemplates(userId: user.id);
  }

  Future<void> saveRecipe(StockRecipe recipe) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(recipesDatasourceProvider).saveRecipe(recipe);
    });
  }

  Future<void> deactivateRecipe(String recipeId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(recipesDatasourceProvider).deactivateRecipe(recipeId);
    });
  }

  Future<void> executeRecipe(StockRecipe recipe) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Usuário não autenticado');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(recipesDatasourceProvider).executeRecipe(
            recipe: recipe,
            userId: user.id,
            userName: user.name,
          );
    });
  }
}

final recipesNotifierProvider =
    AsyncNotifierProvider<RecipesNotifier, void>(RecipesNotifier.new);
