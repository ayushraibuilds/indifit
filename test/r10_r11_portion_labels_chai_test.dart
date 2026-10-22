import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/features/food_log/food_staple_suggestions.dart';
import 'package:indifit/features/food_log/my_chai.dart';
import 'package:indifit/features/food_log/widgets/food_portion_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// R-11 serving chips from their own weights; R-10 black tea and vegans.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('serving chip labels (R-11)', () {
    String label(
      String unit,
      double weight, {
      bool liquid = false,
      bool myKatori = false,
      bool myGlass = false,
    }) => FoodPortionBottomSheet.servingOptionChipLabel(
      ServingOption(unitName: unit, gramWeight: weight),
      liquid: liquid,
      myKatori: myKatori,
      myGlass: myGlass,
    );

    test('say the option\'s own weight, not a fixed one', () {
      expect(label('katori', 150), '1 Katori (150 g)');
      expect(label('katori', 180), '1 Katori (180 g)');
      expect(label('roti_piece', 40), '1 Roti (40 g)');
      expect(label('100g', 100), '100 g');
      expect(label('custom_cup', 120), 'custom cup (120 g)');
    });

    test('liquids say ml, solids g', () {
      expect(label('glass', 206), '1 Glass (206 ml)');
      expect(label('katori', 150, liquid: true), '1 Katori (150 ml)');
      expect(label('tablespoon', 15), '1 Tbsp (15 g)');
    });

    test('My katori and My glass use the calibrated size', () {
      final options = FoodPortionBottomSheet.calibratedServingOptions(
        const [
          ServingOption(unitName: 'katori', gramWeight: 150, isDefault: true),
          ServingOption(unitName: 'glass', gramWeight: 206),
          ServingOption(unitName: 'small_katori', gramWeight: 80),
        ],
        myKatoriMillilitres: 200,
        myGlassMillilitres: 300,
      );
      expect(options[0].gramWeight, 200);
      expect(options[0].isDefault, isTrue);
      expect(options[1].gramWeight, 300);
      expect(options[2].gramWeight, 80);
      expect(
        FoodPortionBottomSheet.servingOptionChipLabel(
          options[0],
          myKatori: true,
        ),
        'My katori (200 g)',
      );
      expect(
        FoodPortionBottomSheet.servingOptionChipLabel(
          options[1],
          myGlass: true,
        ),
        'My glass (300 ml)',
      );
    });

    test('without a calibration nothing changes', () {
      const options = [ServingOption(unitName: 'katori', gramWeight: 150)];
      expect(
        FoodPortionBottomSheet.calibratedServingOptions(options).single,
        options.single,
      );
    });
  });

  group('My chai and diets (R-10)', () {
    const milky = MyChaiSettings.defaults;
    final black = MyChaiSettings.defaults.copyWith(
      milkShare: MyChaiMilkShare.none,
    );

    test('a vegan is offered black tea, not a milky chai', () {
      expect(myChaiFitsDiet(milky, 'vegan'), isFalse);
      expect(myChaiFitsDiet(milky, 'Vegan '), isFalse);
      expect(myChaiFitsDiet(black, 'vegan'), isTrue);
      expect(myChaiFitsDiet(milky, 'veg'), isTrue);
      expect(myChaiFitsDiet(milky, null), isTrue);
    });

    test('offeredMyChaiProvider follows the diet', () async {
      Future<MyChaiSettings?> offered(MyChaiSettings chai, String diet) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await chai.write(prefs);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userProfileProvider.overrideWith((ref) => _DietNotifier(diet)),
          ],
        );
        addTearDown(container.dispose);
        return container.read(offeredMyChaiProvider);
      }

      expect(await offered(milky, 'vegan'), isNull);
      expect(await offered(black, 'vegan'), black);
      expect(await offered(milky, 'veg'), milky);
    });

    test('search starter chips leave Chai out for vegans', () {
      expect(
        foodStapleSuggestions(mealType: 'snack', diet: 'vegan'),
        isNot(contains('Chai')),
      );
      expect(foodStapleSuggestions(mealType: 'snack'), contains('Chai'));
    });

    test('settings saved before black tea still read back', () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.prefMyChaiMilk: 'toned',
        AppPreferenceKeys.prefMyChaiMilkShare: 'half',
        AppPreferenceKeys.prefMyChaiSugarTsp: 1.0,
        AppPreferenceKeys.prefMyChaiCupMl: 150,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(MyChaiSettings.read(prefs), MyChaiSettings.defaults);
      await black.write(prefs);
      expect(MyChaiSettings.read(prefs), black);
      expect(MyChaiSettings.read(prefs)!.milkMillilitres, 0);
    });
  });
}

class _DietNotifier extends UserProfileNotifier {
  _DietNotifier(String diet) : super() {
    state = UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 100,
      carbsGoal: 250,
      fatGoal: 60,
      currentWeight: 70,
      userHeight: 170,
      userName: 'Test',
      userSex: 'female',
      userAge: 30,
      userActivityLevel: 'moderate',
      userGoal: 'maintain',
      dietPreference: diet,
    );
  }

  @override
  Future<void> loadProfile() async {}
}
