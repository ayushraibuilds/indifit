import '../models/b02_execution_models.dart';

class B02EquipmentIncrementInput {
  final double? effectiveItemIncrementKg;
  final double? profileDefaultIncrementKg;

  const B02EquipmentIncrementInput({
    this.effectiveItemIncrementKg,
    this.profileDefaultIncrementKg,
  });
}

enum B02EquipmentIncrementSource {
  effectiveItem('effectiveItem'),
  profileDefault('profileDefault'),
  unavailable('unavailable');

  final String dbValue;

  const B02EquipmentIncrementSource(this.dbValue);
}

class B02EquipmentIncrementResolution {
  final double? incrementKg;
  final B02EquipmentIncrementSource source;
  final String reason;

  const B02EquipmentIncrementResolution({
    required this.incrementKg,
    required this.source,
    required this.reason,
  });

  bool get isAvailable => incrementKg != null;
}

/// Resolves only frozen numeric equipment facts. It does not inspect exercise
/// names or choose a substitute equipment item.
class B02EquipmentIncrementResolver {
  const B02EquipmentIncrementResolver();

  B02EquipmentIncrementResolution resolve(B02EquipmentIncrementInput input) {
    final item = _positiveFinite(input.effectiveItemIncrementKg);
    if (item != null) {
      return B02EquipmentIncrementResolution(
        incrementKg: item,
        source: B02EquipmentIncrementSource.effectiveItem,
        reason: 'Using the frozen equipment-item increment.',
      );
    }
    final profile = _positiveFinite(input.profileDefaultIncrementKg);
    if (profile != null) {
      return B02EquipmentIncrementResolution(
        incrementKg: profile,
        source: B02EquipmentIncrementSource.profileDefault,
        reason: 'Using the frozen equipment-profile default increment.',
      );
    }
    return const B02EquipmentIncrementResolution(
      incrementKg: null,
      source: B02EquipmentIncrementSource.unavailable,
      reason: 'No positive equipment increment is known.',
    );
  }

  static double? _positiveFinite(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }
}

class B02WarmupRequest {
  final B02WarmupPreference? preference;
  final int? requestedCount;
  final B02WarmupLoadCandidate? userEditedTarget;
  final B02WarmupLoadCandidate? targetRecommendation;
  final B02WarmupLoadCandidate? prescription;
  final B02WarmupLoadCandidate? recentComparable;
  final B02EquipmentIncrementInput incrementInput;

  const B02WarmupRequest({
    this.preference,
    this.requestedCount,
    this.userEditedTarget,
    this.targetRecommendation,
    this.prescription,
    this.recentComparable,
    this.incrementInput = const B02EquipmentIncrementInput(),
  });
}

/// Pure B02-D07 warm-up calculation. All inputs are explicit snapshots or
/// candidates supplied by repositories; this service performs no reads or
/// writes and never invents a working load.
class WarmupRecommendationService {
  static const String ruleVersion = B02WarmupRecommendation.ruleVersion;

  static const _percentages = <int, List<double>>{
    1: [50],
    2: [40, 70],
    3: [40, 60, 80],
    4: [30, 45, 60, 80],
  };

  static const _reps = <int, List<int>>{
    1: [5],
    2: [5, 3],
    3: [5, 3, 2],
    4: [6, 4, 3, 2],
  };

  const WarmupRecommendationService();

  B02WarmupRecommendation recommend(B02WarmupRequest request) {
    final count = (request.requestedCount ?? 3).clamp(1, 4).toInt();
    if (request.preference == B02WarmupPreference.off) {
      return _unavailable(
        request,
        count,
        'Warm-up preference is explicitly off.',
      );
    }

    final candidate = _selectCandidate(request);
    if (candidate == null) {
      return _unavailable(
        request,
        count,
        'No working target is available for a warm-up ramp.',
      );
    }
    if (candidate.loadBasis == null) {
      return _unavailable(
        request,
        count,
        'The selected warm-up target has no load basis.',
        source: candidate.source,
      );
    }

    if (candidate.loadBasis == B02LoadBasis.bodyweight) {
      if (candidate.loadKg != null) {
        return _unavailable(
          request,
          count,
          'Bodyweight targets cannot carry an external working load.',
          source: candidate.source,
        );
      }
      return B02WarmupRecommendation(
        availability: B02WarmupAvailability.available,
        preference: request.preference,
        selectedSource: candidate.source,
        loadBasis: B02LoadBasis.bodyweight,
        workingLoadKg: null,
        requestedCount: count,
        incrementKg: null,
        incrementUnavailable: false,
        reason: 'Bodyweight technique-preparation warm-up is available.',
        completeness: {
          'targetKnown': true,
          'incrementKnown': true,
          'preferenceKnown': request.preference != null,
        },
        proposals: [
          B02WarmupSetProposal(
            ordinal: 0,
            loadKg: null,
            loadBasis: B02LoadBasis.bodyweight,
            reps: 5,
            techniquePreparation: true,
          ),
        ],
      );
    }

    final workingLoad = _positiveFinite(candidate.loadKg);
    if (workingLoad == null) {
      return _unavailable(
        request,
        count,
        'The selected working target is malformed or unavailable.',
        source: candidate.source,
      );
    }

    final increment = const B02EquipmentIncrementResolver().resolve(
      request.incrementInput,
    );
    final percentages = _percentages[count]!;
    final reps = _reps[count]!;
    final rawProposals = <B02WarmupSetProposal>[];
    for (var index = 0; index < percentages.length; index++) {
      final percentage = percentages[index];
      final rawLoad = workingLoad * percentage / 100;
      final load = increment.isAvailable
          ? _roundToIncrement(rawLoad, increment.incrementKg!, workingLoad)
          : _oneDecimal(rawLoad.clamp(0, workingLoad));
      if (load <= 0) continue;
      rawProposals.add(
        B02WarmupSetProposal(
          ordinal: rawProposals.length,
          percentageOfWorkingLoad: percentage,
          loadKg: load,
          loadBasis: candidate.loadBasis!,
          reps: reps[index],
        ),
      );
    }

    final proposals = _collapseDuplicateLoads(rawProposals);
    if (proposals.isEmpty && increment.isAvailable) {
      return _available(
        request,
        count,
        candidate,
        increment,
        proposals: const [],
        reason: 'Working load is already light; no ramp is needed.',
      );
    }
    if (proposals.isNotEmpty &&
        proposals.every((proposal) => proposal.loadKg == workingLoad)) {
      final lower = increment.isAvailable
          ? _roundToIncrement(
              workingLoad - increment.incrementKg!,
              increment.incrementKg!,
              workingLoad,
            )
          : 0.0;
      if (lower > 0 && lower < workingLoad) {
        final first = proposals.first;
        final last = proposals.last;
        return _available(
          request,
          count,
          candidate,
          increment,
          proposals: [
            B02WarmupSetProposal(
              ordinal: 0,
              percentageOfWorkingLoad: first.percentageOfWorkingLoad,
              loadKg: lower,
              loadBasis: candidate.loadBasis!,
              reps: first.reps,
            ),
            B02WarmupSetProposal(
              ordinal: 1,
              percentageOfWorkingLoad: last.percentageOfWorkingLoad,
              loadKg: workingLoad,
              loadBasis: candidate.loadBasis!,
              reps: last.reps,
            ),
          ],
          reason: 'Working load is very light; the ramp was collapsed safely.',
        );
      }
      return _available(
        request,
        count,
        candidate,
        increment,
        proposals: const [],
        reason: 'Working load is already light; no ramp is needed.',
      );
    }

    return _available(
      request,
      count,
      candidate,
      increment,
      proposals: proposals,
      reason: increment.isAvailable
          ? 'Warm-up ramp rounded to the frozen equipment increment.'
          : 'Warm-up ramp uses one-decimal loads because no increment is known.',
    );
  }

  B02WarmupLoadCandidate? _selectCandidate(B02WarmupRequest request) {
    for (final candidate in [
      request.userEditedTarget,
      request.targetRecommendation,
      request.prescription,
      request.recentComparable,
    ]) {
      if (candidate != null) return candidate;
    }
    return null;
  }

  B02WarmupRecommendation _available(
    B02WarmupRequest request,
    int count,
    B02WarmupLoadCandidate candidate,
    B02EquipmentIncrementResolution increment, {
    required List<B02WarmupSetProposal> proposals,
    required String reason,
  }) {
    return B02WarmupRecommendation(
      availability: B02WarmupAvailability.available,
      preference: request.preference,
      selectedSource: candidate.source,
      loadBasis: candidate.loadBasis,
      workingLoadKg: candidate.loadKg,
      requestedCount: count,
      incrementKg: increment.incrementKg,
      incrementUnavailable: !increment.isAvailable,
      reason: reason,
      completeness: {
        'targetKnown': true,
        'incrementKnown': increment.isAvailable,
        'preferenceKnown': request.preference != null,
      },
      proposals: proposals,
    );
  }

  B02WarmupRecommendation _unavailable(
    B02WarmupRequest request,
    int count,
    String reason, {
    B02WarmupTargetSource? source,
  }) {
    return B02WarmupRecommendation(
      availability: B02WarmupAvailability.unavailable,
      preference: request.preference,
      selectedSource: null,
      loadBasis: null,
      workingLoadKg: null,
      requestedCount: count,
      incrementKg: null,
      incrementUnavailable: false,
      reason: reason,
      completeness: {
        'targetKnown': false,
        'incrementKnown': false,
        'preferenceKnown': request.preference != null,
        if (source != null) 'candidateProvided': true,
      },
      proposals: const [],
    );
  }

  static List<B02WarmupSetProposal> _collapseDuplicateLoads(
    List<B02WarmupSetProposal> proposals,
  ) {
    final collapsed = <B02WarmupSetProposal>[];
    final seen = <String>{};
    for (final proposal in proposals) {
      final key = proposal.loadKg!.toStringAsFixed(6);
      if (!seen.add(key)) continue;
      collapsed.add(
        B02WarmupSetProposal(
          ordinal: collapsed.length,
          percentageOfWorkingLoad: proposal.percentageOfWorkingLoad,
          loadKg: proposal.loadKg,
          loadBasis: proposal.loadBasis,
          reps: proposal.reps,
        ),
      );
    }
    return collapsed;
  }

  static double _roundToIncrement(
    double value,
    double increment,
    double workingLoad,
  ) {
    final rounded = (value / increment).round() * increment;
    return _oneDecimal(rounded.clamp(0, workingLoad));
  }

  static double _oneDecimal(num value) =>
      double.parse(value.toDouble().toStringAsFixed(1));

  static double? _positiveFinite(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }
}
