import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' as database;

/// The single persistence and ownership boundary for B03 household measures.
///
/// This repository stores standard definitions only when they have a reviewed
/// volume contract. Unresolved vocabulary remains in the typed manifest and
/// is returned as an explicit unavailable result; no placeholder volume is
/// written to the database.
class NutritionHouseholdMeasureRepository {
  final database.AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionHouseholdMeasureConversionService _conversionService;

  NutritionHouseholdMeasureRepository({
    required database.AppDatabase db,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionHouseholdMeasureConversionService? conversionService,
  }) : _db = db,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _conversionService =
           conversionService ??
           const NutritionHouseholdMeasureConversionService();

  Future<List<NutritionHouseholdMeasureDefinition>>
  listStandardMeasures() async {
    await _ensureReviewedStandardMeasures();
    return NutritionStandardHouseholdMeasures.definitions;
  }

  Future<NutritionHouseholdMeasureDefinition> getStandardMeasure(
    String measureId,
  ) async {
    await _ensureReviewedStandardMeasures();
    return NutritionStandardHouseholdMeasures.byId(measureId);
  }

  Future<NutritionPersonalVessel> createVessel({
    required String userId,
    required String displayName,
    String? vesselType,
    String? portableId,
  }) async {
    _validateOwner(userId);
    _validateDisplayName(displayName);
    final id = _portableId(portableId, entity: 'vessel');
    final existing = await (_db.select(
      _db.nutritionPersonalVessels,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      throw const NutritionHouseholdMeasureException(
        'duplicate_vessel_portable_id',
        'A personal vessel with this portable ID already exists.',
      );
    }

    final now = _nowUtc();
    await _db
        .into(_db.nutritionPersonalVessels)
        .insert(
          database.NutritionPersonalVesselsCompanion.insert(
            id: id,
            userId: userId.trim(),
            displayName: displayName.trim(),
            vesselType: vesselType == null || vesselType.trim().isEmpty
                ? const Value.absent()
                : Value(vesselType.trim()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return _vesselFromRow(
      (await (_db.select(
        _db.nutritionPersonalVessels,
      )..where((row) => row.id.equals(id))).getSingle()),
    );
  }

  Future<List<NutritionPersonalVessel>> listVessels({
    required String userId,
    bool includeArchived = false,
  }) async {
    _validateOwner(userId);
    final query = _db.select(_db.nutritionPersonalVessels)
      ..where((row) => row.userId.equals(userId.trim()));
    if (!includeArchived) {
      query.where((row) => row.archivedAt.isNull());
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.createdAt),
      (row) => OrderingTerm(expression: row.id),
    ]);
    final rows = await query.get();
    return rows.map(_vesselFromRow).toList(growable: false);
  }

  Future<NutritionPersonalVessel> getVessel({
    required String userId,
    required String vesselId,
  }) async {
    _validateOwner(userId);
    return _ownedVessel(userId: userId, vesselId: vesselId);
  }

  Future<NutritionPersonalVessel> renameVessel({
    required String userId,
    required String vesselId,
    required String displayName,
  }) async {
    _validateDisplayName(displayName);
    final normalizedVesselId = vesselId.trim();
    await _ownedVessel(userId: userId, vesselId: normalizedVesselId);
    final now = _nowUtc();
    await (_db.update(
      _db.nutritionPersonalVessels,
    )..where((row) => row.id.equals(normalizedVesselId))).write(
      database.NutritionPersonalVesselsCompanion(
        displayName: Value(displayName.trim()),
        updatedAt: Value(now),
      ),
    );
    return _ownedVessel(userId: userId, vesselId: normalizedVesselId);
  }

  Future<NutritionPersonalVessel> archiveVessel({
    required String userId,
    required String vesselId,
  }) async {
    final normalizedVesselId = vesselId.trim();
    final vessel = await _ownedVessel(
      userId: userId,
      vesselId: normalizedVesselId,
    );
    if (vessel.isArchived) return vessel;
    final now = _nowUtc();
    await (_db.update(
      _db.nutritionPersonalVessels,
    )..where((row) => row.id.equals(normalizedVesselId))).write(
      database.NutritionPersonalVesselsCompanion(
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return _ownedVessel(userId: userId, vesselId: normalizedVesselId);
  }

  Future<List<NutritionVesselCalibration>> getCalibrationHistory({
    required String userId,
    required String vesselId,
  }) async {
    final normalizedVesselId = vesselId.trim();
    await _ownedVessel(userId: userId, vesselId: normalizedVesselId);
    final rows =
        await (_db.select(_db.nutritionVesselCalibrations)
              ..where((row) => row.vesselId.equals(normalizedVesselId))
              ..orderBy([
                (row) => OrderingTerm(expression: row.version),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    final calibrations = rows.map(_calibrationFromRow).toList(growable: false);
    _validateCalibrationGraph(calibrations, vesselId: normalizedVesselId);
    return calibrations;
  }

  Future<NutritionVesselCalibration?> getCurrentCalibration({
    required String userId,
    required String vesselId,
  }) async {
    final history = await getCalibrationHistory(
      userId: userId,
      vesselId: vesselId,
    );
    if (history.isEmpty) return null;
    final supersededIds = history
        .map((row) => row.supersedesCalibrationId)
        .whereType<String>()
        .toSet();
    final terminals = history
        .where((row) => !supersededIds.contains(row.id))
        .toList(growable: false);
    if (terminals.length != 1) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_graph',
        'A vessel must have exactly one current calibration.',
      );
    }
    return terminals.single;
  }

  Future<NutritionVesselCalibration> getCalibration({
    required String userId,
    required String calibrationId,
  }) async {
    _validateOwner(userId);
    final normalizedCalibrationId = calibrationId.trim();
    final row =
        await (_db.select(_db.nutritionVesselCalibrations)..where(
              (calibration) => calibration.id.equals(normalizedCalibrationId),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw NutritionHouseholdMeasureException(
        'missing_calibration',
        'No calibration exists for portable ID $normalizedCalibrationId.',
      );
    }
    await _ownedVessel(userId: userId, vesselId: row.vesselId);
    return _calibrationFromRow(row);
  }

  /// Adds a successor calibration in one transaction. The repository derives
  /// the supersession edge from the current terminal; callers cannot attach a
  /// calibration to another vessel or mutate an historical row.
  Future<NutritionVesselCalibration> addCalibration({
    required String userId,
    required String vesselId,
    required Quantity volume,
    required String method,
    QuantityAmount? lower,
    QuantityAmount? upper,
    double? confidence,
    String? notes,
    String? portableId,
  }) async {
    _validateOwner(userId);
    final normalizedVesselId = vesselId.trim();
    if (volume.unit != QuantityUnit.millilitre &&
        volume.unit != QuantityUnit.litre) {
      throw const NutritionHouseholdMeasureException(
        'unsupported_volume_unit',
        'Vessel calibration accepts only millilitres or litres.',
      );
    }
    if (volume.isZero) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_volume',
        'Calibration volume must be greater than zero.',
      );
    }
    if (method.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_method',
        'Calibration method is required.',
      );
    }
    if (confidence != null &&
        (!confidence.isFinite || confidence < 0 || confidence > 1)) {
      throw const NutritionHouseholdMeasureException(
        'invalid_confidence',
        'Calibration confidence must be finite and between 0 and 1.',
      );
    }
    final range = NutritionVolumeRange(
      unit: volume.unit,
      lower: lower,
      point: volume.amount,
      upper: upper,
    );
    final id = _portableId(portableId, entity: 'calibration');
    _storageDouble(range.point!, field: 'calibration volume');
    if (range.lower != null) _storageDouble(range.lower!, field: 'lower bound');
    if (range.upper != null) _storageDouble(range.upper!, field: 'upper bound');

    return _db.transaction(() async {
      final vessel = await _ownedVessel(
        userId: userId,
        vesselId: normalizedVesselId,
      );
      if (vessel.isArchived) {
        throw const NutritionHouseholdMeasureException(
          'archived_vessel',
          'Archived vessels cannot receive new calibrations.',
        );
      }
      final duplicate = await (_db.select(
        _db.nutritionVesselCalibrations,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (duplicate != null) {
        throw const NutritionHouseholdMeasureException(
          'duplicate_calibration_portable_id',
          'A calibration with this portable ID already exists.',
        );
      }
      final history = await _readCalibrationHistory(normalizedVesselId);
      final current = _currentFromHistory(
        history,
        vesselId: normalizedVesselId,
      );
      final now = _nowUtc();
      await _db
          .into(_db.nutritionVesselCalibrations)
          .insert(
            database.NutritionVesselCalibrationsCompanion.insert(
              id: id,
              vesselId: normalizedVesselId,
              volumeAmount: range.point!.asDouble,
              volumeUnit: volume.unit.name,
              lower: range.lower == null
                  ? const Value.absent()
                  : Value(range.lower!.asDouble),
              upper: range.upper == null
                  ? const Value.absent()
                  : Value(range.upper!.asDouble),
              method: method.trim(),
              confidence: confidence == null
                  ? const Value.absent()
                  : Value(confidence),
              supersedesCalibrationId: current == null
                  ? const Value.absent()
                  : Value(current.id),
              version: current == null ? 1 : current.version + 1,
              notes: notes == null || notes.trim().isEmpty
                  ? const Value.absent()
                  : Value(notes.trim()),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      final inserted = await (_db.select(
        _db.nutritionVesselCalibrations,
      )..where((row) => row.id.equals(id))).getSingle();
      return _calibrationFromRow(inserted);
    });
  }

  Future<NutritionMeasureToVolumeResult> convertToVolume({
    required String userId,
    required NutritionMeasureSelection selection,
    required Quantity count,
    bool allowArchived = false,
  }) async {
    _validateOwner(userId);
    if (count.unit != QuantityUnit.piece) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_count_unit',
        'A household measure count must use the typed piece unit.',
      );
    }
    if (count.isZero) {
      throw const NutritionHouseholdMeasureException(
        'invalid_measure_count',
        'A household measure count must be greater than zero.',
      );
    }

    if (selection is NutritionStandardMeasureSelection) {
      final definition = await getStandardMeasure(selection.measureId);
      if (!definition.hasReviewedVolume) {
        return NutritionMeasureConversionUnresolved(
          selectionId: selection.measureId,
          code: 'unresolved_measure_definition',
          message:
              '${definition.displayName} has no reviewed volume definition.',
          missingContext: 'reviewed_volume_definition',
        );
      }
      return _conversionService.scale(
        selectionId: selection.measureId,
        count: count,
        volume: definition.volume!,
        source: NutritionHouseholdMeasureSource.reviewedStandard,
        definitionVersion: definition.version,
      );
    }

    if (selection is NutritionPersonalVesselSelection) {
      final vessel = await _ownedVessel(
        userId: userId,
        vesselId: selection.vesselId,
      );
      if (vessel.isArchived && !allowArchived) {
        return NutritionMeasureConversionUnresolved(
          selectionId: vessel.id,
          code: 'archived_vessel',
          message: 'Archived vessels are not available for new entry.',
          missingContext: 'active_personal_vessel',
        );
      }
      final calibration = await getCurrentCalibration(
        userId: userId,
        vesselId: vessel.id,
      );
      if (calibration == null) {
        return NutritionMeasureConversionUnresolved(
          selectionId: vessel.id,
          code: 'missing_calibration',
          message: 'This vessel has no calibrated volume yet.',
          missingContext: 'current_vessel_calibration',
        );
      }
      return _conversionService.scale(
        selectionId: vessel.id,
        count: count,
        volume: calibration.volume,
        source: NutritionHouseholdMeasureSource.userCalibration,
        calibrationId: calibration.id,
        calibrationVersion: calibration.version,
      );
    }

    throw const NutritionHouseholdMeasureException(
      'unsupported_measure_selection',
      'This household-measure selection type is not supported.',
    );
  }

  Future<void> _ensureReviewedStandardMeasures() async {
    await _db.transaction(() async {
      final now = _nowUtc();
      for (final definition in NutritionStandardHouseholdMeasures.definitions) {
        if (!definition.hasReviewedVolume) continue;
        final existing = await (_db.select(
          _db.nutritionHouseholdMeasures,
        )..where((row) => row.id.equals(definition.id))).getSingleOrNull();
        final volume = definition.volume!;
        if (existing == null) {
          await _db
              .into(_db.nutritionHouseholdMeasures)
              .insert(
                database.NutritionHouseholdMeasuresCompanion.insert(
                  id: definition.id,
                  key: definition.key,
                  displayName: definition.displayName,
                  dimension: definition.dimension.stableId,
                  baseUnit: definition.baseUnit.name,
                  nominalValue: _storageDouble(
                    volume.point!,
                    field: '${definition.key} volume',
                  ),
                  lower: volume.lower == null
                      ? const Value.absent()
                      : Value(
                          _storageDouble(volume.lower!, field: 'lower bound'),
                        ),
                  upper: volume.upper == null
                      ? const Value.absent()
                      : Value(
                          _storageDouble(volume.upper!, field: 'upper bound'),
                        ),
                  locale: definition.locale,
                  version: definition.version,
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
          continue;
        }
        if (existing.key != definition.key ||
            existing.displayName != definition.displayName ||
            existing.dimension != definition.dimension.stableId ||
            existing.baseUnit != definition.baseUnit.name ||
            existing.version != definition.version ||
            _amountFromStorage(existing.nominalValue) != volume.point ||
            _optionalAmountFromStorage(existing.lower) != volume.lower ||
            _optionalAmountFromStorage(existing.upper) != volume.upper) {
          throw NutritionHouseholdMeasureException(
            'conflicting_measure_definition',
            'Persisted standard measure ${definition.id} does not match the reviewed definition.',
          );
        }
      }
    });
  }

  Future<NutritionPersonalVessel> _ownedVessel({
    required String userId,
    required String vesselId,
  }) async {
    _validateOwner(userId);
    if (vesselId.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'missing_vessel_id',
        'A vessel portable ID is required.',
      );
    }
    final row = await (_db.select(
      _db.nutritionPersonalVessels,
    )..where((vessel) => vessel.id.equals(vesselId.trim()))).getSingleOrNull();
    if (row == null) {
      throw NutritionHouseholdMeasureException(
        'invalid_vessel_id',
        'No personal vessel exists for portable ID $vesselId.',
      );
    }
    if (row.userId != userId.trim()) {
      throw const NutritionHouseholdMeasureException(
        'vessel_ownership_mismatch',
        'A personal vessel belongs to another user scope.',
      );
    }
    return _vesselFromRow(row);
  }

  Future<List<NutritionVesselCalibration>> _readCalibrationHistory(
    String vesselId,
  ) async {
    final rows =
        await (_db.select(_db.nutritionVesselCalibrations)
              ..where((row) => row.vesselId.equals(vesselId))
              ..orderBy([
                (row) => OrderingTerm(expression: row.version),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    final values = rows.map(_calibrationFromRow).toList(growable: false);
    _validateCalibrationGraph(values, vesselId: vesselId);
    return values;
  }

  NutritionVesselCalibration? _currentFromHistory(
    List<NutritionVesselCalibration> history, {
    required String vesselId,
  }) {
    if (history.isEmpty) return null;
    final supersededIds = history
        .map((row) => row.supersedesCalibrationId)
        .whereType<String>()
        .toSet();
    final terminals = history
        .where((row) => !supersededIds.contains(row.id))
        .toList(growable: false);
    if (terminals.length != 1) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_graph',
        'A vessel must have exactly one current calibration.',
      );
    }
    return terminals.single;
  }

  void _validateCalibrationGraph(
    List<NutritionVesselCalibration> history, {
    required String vesselId,
  }) {
    if (history.isEmpty) return;
    final byId = {for (final row in history) row.id: row};
    final childIds = <String>{};
    var roots = 0;
    for (final row in history) {
      if (row.vesselId != vesselId) {
        throw const NutritionHouseholdMeasureException(
          'calibration_vessel_mismatch',
          'Calibration history contains a record for another vessel.',
        );
      }
      final parentId = row.supersedesCalibrationId;
      if (parentId == null) {
        roots++;
        if (row.version != 1) {
          throw const NutritionHouseholdMeasureException(
            'invalid_calibration_ancestry',
            'The root calibration must have version 1.',
          );
        }
        continue;
      }
      final parent = byId[parentId];
      if (parent == null || parent.vesselId != row.vesselId) {
        throw const NutritionHouseholdMeasureException(
          'invalid_calibration_ancestry',
          'Calibration supersession must remain within one vessel.',
        );
      }
      if (row.version != parent.version + 1) {
        throw const NutritionHouseholdMeasureException(
          'invalid_calibration_ancestry',
          'Calibration versions must increase by one along supersession.',
        );
      }
      if (!childIds.add(parent.id)) {
        throw const NutritionHouseholdMeasureException(
          'invalid_calibration_graph',
          'A calibration may have only one successor.',
        );
      }
    }
    if (roots != 1) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_graph',
        'A vessel calibration graph must have exactly one root.',
      );
    }
    final terminals = history.where((row) => !childIds.contains(row.id));
    if (terminals.length != 1) {
      throw const NutritionHouseholdMeasureException(
        'invalid_calibration_graph',
        'A vessel calibration graph must have exactly one current terminal.',
      );
    }
  }

  NutritionPersonalVessel _vesselFromRow(
    database.NutritionPersonalVessel row,
  ) => NutritionPersonalVessel(
    id: row.id,
    userId: row.userId,
    displayName: row.displayName,
    vesselType: row.vesselType,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    archivedAt: row.archivedAt,
  );

  NutritionVesselCalibration _calibrationFromRow(
    database.NutritionVesselCalibration row,
  ) {
    final unit = switch (row.volumeUnit) {
      'millilitre' => QuantityUnit.millilitre,
      'litre' => QuantityUnit.litre,
      _ => throw NutritionHouseholdMeasureException(
        'unsupported_volume_unit',
        'Unsupported persisted calibration unit ${row.volumeUnit}.',
      ),
    };
    return NutritionVesselCalibration(
      id: row.id,
      vesselId: row.vesselId,
      volume: NutritionVolumeRange(
        unit: unit,
        lower: _optionalAmountFromStorage(row.lower),
        point: _amountFromStorage(row.volumeAmount),
        upper: _optionalAmountFromStorage(row.upper),
      ),
      method: row.method,
      confidence: row.confidence,
      supersedesCalibrationId: row.supersedesCalibrationId,
      version: row.version,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static void _validateOwner(String userId) {
    if (userId.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'missing_user_id',
        'A user ownership scope is required.',
      );
    }
  }

  static void _validateDisplayName(String displayName) {
    if (displayName.trim().isEmpty) {
      throw const NutritionHouseholdMeasureException(
        'invalid_vessel_name',
        'A vessel display name is required.',
      );
    }
  }

  String _portableId(String? requested, {required String entity}) {
    final id = requested == null || requested.trim().isEmpty
        ? '${entity}_v1_${_uuid.v4()}'
        : requested.trim();
    if (id.isEmpty) {
      throw NutritionHouseholdMeasureException(
        'missing_${entity}_portable_id',
        'A portable $entity ID is required.',
      );
    }
    return id;
  }

  static double _storageDouble(QuantityAmount amount, {required String field}) {
    final value = amount.asDouble;
    if (!value.isFinite || value <= 0) {
      throw NutritionHouseholdMeasureException(
        'precision_overflow',
        '$field cannot be represented as a finite positive storage value.',
      );
    }
    final roundTrip = QuantityAmount.fromNum(value);
    if (roundTrip != amount) {
      throw NutritionHouseholdMeasureException(
        'precision_overflow',
        '$field exceeds the exact decimal precision supported by schema v17.',
      );
    }
    return value;
  }

  static QuantityAmount _amountFromStorage(double value) {
    if (!value.isFinite || value <= 0) {
      throw const NutritionHouseholdMeasureException(
        'invalid_persisted_volume',
        'Persisted volume must be finite and positive.',
      );
    }
    return QuantityAmount.fromNum(value);
  }

  static QuantityAmount? _optionalAmountFromStorage(double? value) {
    if (value == null) return null;
    return _amountFromStorage(value);
  }
}
