/// B04-12 focused fixture manifest.
///
/// The values are scenario metadata only; production evaluation consumes the
/// typed B03/B04 read models rather than this fixture list.
enum B04CurrentFoodFixtureKind { positive, boundary, negative }

class B04CurrentFoodFixture {
  final String id;
  final B04CurrentFoodFixtureKind kind;
  final String requirement;
  final String expectedOutcome;

  const B04CurrentFoodFixture({
    required this.id,
    required this.kind,
    required this.requirement,
    required this.expectedOutcome,
  });
}

class B04CurrentFoodFixtureMatrix {
  B04CurrentFoodFixtureMatrix._();

  static const List<B04CurrentFoodFixture> cases = [
    B04CurrentFoodFixture(
      id: 'local_candidate_ranking',
      kind: B04CurrentFoodFixtureKind.positive,
      requirement: 'trusted local candidates with known remaining targets',
      expectedOutcome: 'available',
    ),
    B04CurrentFoodFixture(
      id: 'no_explicit_candidate',
      kind: B04CurrentFoodFixtureKind.boundary,
      requirement: 'explicit meal opportunity without a selected candidate',
      expectedOutcome: 'no_candidate',
    ),
    B04CurrentFoodFixture(
      id: 'known_consumed_totals',
      kind: B04CurrentFoodFixtureKind.positive,
      requirement: 'known B03 consumed totals',
      expectedOutcome: 'remaining point is derived with source lineage',
    ),
    B04CurrentFoodFixture(
      id: 'estimated_consumed_range',
      kind: B04CurrentFoodFixtureKind.boundary,
      requirement: 'estimated B03 totals with lower and upper bounds',
      expectedOutcome: 'remaining range is preserved',
    ),
    B04CurrentFoodFixture(
      id: 'missing_consumed_totals',
      kind: B04CurrentFoodFixtureKind.negative,
      requirement: 'missing daily totals',
      expectedOutcome: 'unavailable; missing is never zero',
    ),
    B04CurrentFoodFixture(
      id: 'confirmed_allergy_hard_block',
      kind: B04CurrentFoodFixtureKind.negative,
      requirement: 'confirmed strict B03 dietary conflict',
      expectedOutcome: 'candidate excluded',
    ),
    B04CurrentFoodFixture(
      id: 'uncertain_safety_evidence',
      kind: B04CurrentFoodFixtureKind.negative,
      requirement:
          'possible, unknown, insufficient, missing or invalid evidence',
      expectedOutcome: 'safety-sensitive guidance unavailable',
    ),
    B04CurrentFoodFixture(
      id: 'offline_local_fallback',
      kind: B04CurrentFoodFixtureKind.positive,
      requirement: 'no network provider',
      expectedOutcome: 'same deterministic local result',
    ),
    B04CurrentFoodFixture(
      id: 'low_risk_logging_acknowledgement',
      kind: B04CurrentFoodFixtureKind.boundary,
      requirement: 'acknowledgement on the separately scoped logging action',
      expectedOutcome: 'warning preserved outside recommendations',
    ),
    B04CurrentFoodFixture(
      id: 'effective_goal_version',
      kind: B04CurrentFoodFixtureKind.boundary,
      requirement: 'goal change across an effective local date',
      expectedOutcome: 'new goal version supplies remaining targets',
    ),
    B04CurrentFoodFixture(
      id: 'no_safety_acknowledgement_bypass',
      kind: B04CurrentFoodFixtureKind.negative,
      requirement: 'acknowledgement or override on safety-sensitive output',
      expectedOutcome: 'B03 safety result remains blocked or unavailable',
    ),
    B04CurrentFoodFixture(
      id: 'n8_absent',
      kind: B04CurrentFoodFixtureKind.boundary,
      requirement: 'festival, fasting, travel and eating-out context',
      expectedOutcome: 'no inference and no N8 dependency',
    ),
  ];
}
