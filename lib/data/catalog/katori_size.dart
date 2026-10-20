import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The katori the catalogue counts in: the app's 150 g / 150 ml katori
/// (`food_catalog_service.dart`, the packs' `app-katori-150g` rule).
const double kStandardKatoriMillilitres = 150;

/// The sizes offered by "Which katori looks like yours?".
const List<double> kKatoriSizeChoicesMillilitres = [100, 150, 200];

/// The personal vessel type that marks "my katori".
const String kMyKatoriVesselType = 'katori';

/// The glass liquids count in until the person says (UR-09): steel glasses
/// are mostly 200–300 ml.
const double kStandardGlassMillilitres = 250;

/// The sizes offered for "My glass".
const List<double> kGlassSizeChoicesMillilitres = [200, 250, 300];

/// The personal vessel type that marks "my glass".
const String kMyGlassVesselType = 'glass';

/// The person's own katori in millilitres: the newest calibration of an
/// active "katori" vessel, or null when they haven't said.
Future<double?> readMyKatoriMillilitres(AppDatabase db) =>
    readMyVesselMillilitres(db, kMyKatoriVesselType);

/// The person's own glass in millilitres, or null when they haven't said.
Future<double?> readMyGlassMillilitres(AppDatabase db) =>
    readMyVesselMillilitres(db, kMyGlassVesselType);

/// The newest calibration of an active vessel of [vesselType], in ml.
Future<double?> readMyVesselMillilitres(
  AppDatabase db,
  String vesselType,
) async {
  final row = await db
      .customSelect(
        'SELECT c.volume_amount AS amount, c.volume_unit AS unit '
        'FROM nutrition_vessel_calibrations c '
        'JOIN nutrition_personal_vessels v ON v.id = c.vessel_id '
        'WHERE v.vessel_type = ? AND v.archived_at IS NULL '
        // The newest choice wins, even across vessels; rowid breaks ties
        // between writes in the same millisecond.
        'ORDER BY c.created_at DESC, c.version DESC, c.rowid DESC LIMIT 1',
        variables: [Variable.withString(vesselType)],
      )
      .getSingleOrNull();
  if (row == null) return null;
  final amount = row.read<double>('amount');
  final millilitres = switch (row.read<String>('unit')) {
    'litre' || 'l' => amount * 1000,
    _ => amount,
  };
  return millilitres > 0 && millilitres.isFinite ? millilitres : null;
}
