# AI evaluation harness (WS7 Phase 5)

Measures the AI meal features end to end: the app's own Gemini prompts and schemas (`lib/core/ai/gemini_requests.dart`) are sent through Firebase AI Logic with App Check, exactly as the app does. The answers then go through the real catalogue matcher. The harness scores **what the review screen shows and what gets logged**.

Run it before every release, and before changing the model (`ai_model`), a prompt (`GeminiRequests.promptVersion`) or the matcher (`MealItemResolver`). **A change that drops below the launch bar doesn't ship.**

## Running

```bash
INDIFIT_APPCHECK_DEBUG_TOKEN=<iOS App Check debug token> flutter test tool/ai_eval/run_eval_test.dart
```

| Variable | Purpose |
|---|---|
| `INDIFIT_APPCHECK_DEBUG_TOKEN` | Required. A debug token registered for the **iOS** app (Firebase console → App Check → Manage debug tokens). Without it the test is skipped. |
| `INDIFIT_AI_MODEL` | Model to evaluate (default `GeminiRequests.defaultModel`). Use this to vet a new model before switching Remote Config. |
| `INDIFIT_AI_EVAL_LIMIT` | Only the first N meals, for a quick smoke test. A subset is not a release gate. |
| `INDIFIT_AI_EVAL_TAGS` | Only meals with these comma-separated tags, e.g. `hinglish,south-indian`. |

A full run makes 64 requests to `gemini-3.8-flash` (roughly 4 minutes, a few rupees). It writes:
- `results/<date>-<model>.md`: metrics, the launch bar, and every item that wasn't auto-matched correctly. Commit it with the change it justifies.
- `results/<date>-<model>.raw.jsonl`: the raw AI answers, for diffing between runs.

`test/ws7_ai_eval_test.dart` runs in CI without calling the AI. It checks the dataset against the catalogue and tests the scoring.

## Metrics and launch bar

| Metric | Meaning | Bar |
|---|---|---|
| Item recall | Expected foods the AI produced an item for | ≥ 90 % |
| Catalogue match | Correct catalogue food auto-matched **or** offered as a choice | ≥ 85 % |
| Wrong auto-match | Auto-matched to the wrong food: a silent error the user may never notice | ≤ 3 % |
| Label fields | Label values read correctly (±1 %), and absent values left empty | ≥ 95 % |
| Auto-matched, amount right, meal kcal error | Tracked, no bar | |

Photo calorie error is reported but has no bar. Photo logging stays **Beta** until you're happy with that number.

## Adding cases

**Meals** (`meals.jsonl`, one JSON object per line):

```json
{"id": "m065", "text": "2 roti aur ek katori dal", "tags": ["hinglish"],
 "items": [{"food": "Whole Wheat Roti / Chapati", "amount": 2},
           {"food": ["Toor Dal / Yellow Dal Tadka", "Yellow Dal Tadka"], "amount": 1}]}
```

- `food`: an exact catalogue name, or a list of acceptable names. The first name is the calorie reference.
- `amount`: counts the food's **own catalogue measure**:
  - pieces, katoris, glasses or servings as listed in `assets/data/indian_foods.json`;
  - grams for per-100 g foods (curd, raw paneer).
  - Example: "4 boiled eggs" is `2`, because the catalogue serving is "Boiled Eggs (2 pieces)".
- Prefer real descriptions from users, with the spelling and Hinglish people actually type. Only use foods that are in the catalogue.

**Nutrition labels** (`labels/`): add a JPEG of a label, up to 2048 px on its longest side (the size the app sends for labels). Then add an entry to `labels/cases.json` with the values printed on its main column:

```json
[{"image": "parle-g.jpg", "basis": "per_100g",
  "fields": {"calories": 454, "protein": 6.9, "carbs": 77.0, "fat": 13.0, "sugar": 25.0, "trans_fat": null}}]
```

Use `null` for a nutrient the label doesn't print. The plan calls for about 20 labels; include FSSAI labels and both per-100 g and per-serving layouts.

**Meal photos** (`photos/`): add a JPEG of a meal, up to 1024 px on its longest side, plus `photos/cases.json` entries `{"image": "thali-1.jpg", "kcal": 650}`. Use weighed ground truth where you can. The plan calls for about 30 photos.

**Strip location metadata from your own photos before committing them** (on macOS: Preview → Tools → Show Inspector → GPS → Remove Location Info).

`test/ws7_ai_eval_test.dart` checks both case files in CI (`ai_eval_data_check.dart`). It fails if:
- an image is missing, isn't a JPEG, or is larger than the app sends;
- an image still carries GPS location;
- a label has an unknown nutrient or basis;
- a photo has no positive `kcal`.

## Before a release

1. About 20 labels in `labels/` and about 30 meal photos in `photos/`, with `flutter test test/ws7_ai_eval_test.dart` green.
2. A full run with the iOS debug token (command above). Commit the `results/` report with the release.
3. Meal text, catalogue match and wrong auto-match must meet the bar. Label field accuracy must meet the bar before label scanning is promoted beyond the AI tools.
4. Meal photo stays labelled **Beta** in the app until you accept its calorie error.

