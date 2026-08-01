/// Typed, JSON-safe contracts for the B02 execution boundary.
///
/// These objects deliberately do not read Drift or infer meaning from display
/// names. Repositories and codecs can use them as the shared contract while
/// later B02 tasks add execution and UI behavior.
library;

class B02ValidationException implements Exception {
  final String message;

  const B02ValidationException(this.message);

  @override
  String toString() => 'B02ValidationException: $message';
}

enum B02ActivityType {
  strength('strength'),
  running('running'),
  cycling('cycling'),
  walking('walking'),
  yoga('yoga'),
  mobility('mobility'),
  legacy('legacy');

  final String dbValue;

  const B02ActivityType(this.dbValue);

  static B02ActivityType parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Activity type must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported activity type "$raw".');
  }
}

enum B02ActivitySource {
  manual('manual'),
  healthImport('healthImport');

  final String dbValue;

  const B02ActivitySource(this.dbValue);

  static B02ActivitySource parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Activity source must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported activity source "$raw".');
  }
}

enum B02GroupType {
  superset('superset'),
  circuit('circuit'),
  giantSet('giantSet');

  final String dbValue;

  const B02GroupType(this.dbValue);

  static B02GroupType parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Group type must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported group type "$raw".');
  }

  bool acceptsMemberCount(int count) => switch (this) {
    B02GroupType.superset => count == 2,
    B02GroupType.circuit => count >= 2,
    B02GroupType.giantSet => count >= 3,
  };
}

enum B02SetRole {
  warmup('warmup'),
  working('working');

  final String dbValue;

  const B02SetRole(this.dbValue);

  static B02SetRole parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Set role must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported set role "$raw".');
  }
}

enum B02EffortMode {
  standard('standard'),
  amrap('amrap'),
  toFailure('toFailure');

  final String dbValue;

  const B02EffortMode(this.dbValue);

  static B02EffortMode parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Effort mode must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported effort mode "$raw".');
  }
}

enum B02LoadBasis {
  totalExternal('totalExternal'),
  perImplement('perImplement'),
  perSide('perSide'),
  bodyweight('bodyweight');

  final String dbValue;

  const B02LoadBasis(this.dbValue);

  static B02LoadBasis parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Load basis must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported load basis "$raw".');
  }
}

enum B02PausedRepPosition {
  bottom('bottom'),
  top('top'),
  midpoint('midpoint'),
  custom('custom');

  final String dbValue;

  const B02PausedRepPosition(this.dbValue);

  static B02PausedRepPosition parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Paused-rep position must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported paused-rep position "$raw".');
  }
}

enum B02AssistanceMode {
  machine('machine'),
  counterweight('counterweight'),
  band('band'),
  partner('partner'),
  unknown('unknown');

  final String dbValue;

  const B02AssistanceMode(this.dbValue);

  static B02AssistanceMode parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Assistance mode must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported assistance mode "$raw".');
  }
}

enum B02CardioSegmentType {
  work('work'),
  recovery('recovery');

  final String dbValue;

  const B02CardioSegmentType(this.dbValue);

  static B02CardioSegmentType parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Cardio segment type must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported cardio segment type "$raw".');
  }
}

enum B02InputMode {
  manual('manual'),
  healthImport('healthImport');

  final String dbValue;

  const B02InputMode(this.dbValue);

  static B02InputMode parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Input mode must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported input mode "$raw".');
  }
}

enum B02RestScope {
  exerciseSet('exerciseSet'),
  groupTransition('groupTransition'),
  groupRound('groupRound'),
  restPause('restPause');

  final String dbValue;

  const B02RestScope(this.dbValue);

  static B02RestScope parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Rest scope must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported rest scope "$raw".');
  }
}

enum B02RestSource {
  user('user'),
  prescription('prescription'),
  exercisePreference('exercisePreference'),
  template('template'),
  automatic('automatic'),
  none('none');

  final String dbValue;

  const B02RestSource(this.dbValue);

  static B02RestSource parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Rest source must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported rest source "$raw".');
  }
}

enum B02RestEndReason {
  elapsed('elapsed'),
  skipped('skipped'),
  nextAction('nextAction'),
  cancelled('cancelled');

  final String dbValue;

  const B02RestEndReason(this.dbValue);

  static B02RestEndReason parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Rest end reason must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported rest end reason "$raw".');
  }
}

enum B02Confidence {
  high('high'),
  medium('medium'),
  low('low'),
  insufficient('insufficient');

  final String dbValue;

  const B02Confidence(this.dbValue);

  static B02Confidence parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Confidence must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported confidence "$raw".');
  }
}

enum B02MappingStatus {
  reviewed('reviewed'),
  unknown('unknown');

  final String dbValue;

  const B02MappingStatus(this.dbValue);

  static B02MappingStatus parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Mapping status must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported mapping status "$raw".');
  }
}

enum B02MuscleRole {
  primary('primary'),
  secondary('secondary'),
  stabilizing('stabilizing');

  final String dbValue;

  const B02MuscleRole(this.dbValue);

  static B02MuscleRole parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Muscle role must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported muscle role "$raw".');
  }
}

String _requiredString(Object? raw, String field) {
  if (raw is! String || raw.trim().isEmpty) {
    throw B02ValidationException('$field must be a non-empty string.');
  }
  return raw;
}

String? _optionalString(Object? raw, String field) {
  if (raw == null) return null;
  return _requiredString(raw, field);
}

int _requiredInt(Object? raw, String field) {
  if (raw is! int) {
    throw B02ValidationException('$field must be an integer.');
  }
  return raw;
}

int? _optionalInt(Object? raw, String field) {
  if (raw == null) return null;
  return _requiredInt(raw, field);
}

double _requiredDouble(Object? raw, String field) {
  if (raw is! num) {
    throw B02ValidationException('$field must be a number.');
  }
  return raw.toDouble();
}

double? _optionalDouble(Object? raw, String field) {
  if (raw == null) return null;
  return _requiredDouble(raw, field);
}

bool _requiredBool(Object? raw, String field) {
  if (raw is! bool) {
    throw B02ValidationException('$field must be a boolean.');
  }
  return raw;
}

Map<String, dynamic> _object(Object? raw, String field) {
  if (raw is! Map) {
    throw B02ValidationException('$field must be an object.');
  }
  return raw.map((key, value) => MapEntry(key.toString(), value));
}

List<dynamic> _list(Object? raw, String field) {
  if (raw is! List) {
    throw B02ValidationException('$field must be an array.');
  }
  return raw;
}

void _nonNegative(num? value, String field) {
  if (value != null && value < 0) {
    throw B02ValidationException('$field must not be negative.');
  }
}

void _positive(num? value, String field) {
  if (value != null && value <= 0) {
    throw B02ValidationException('$field must be positive.');
  }
}

void _atLeast(int value, int minimum, String field) {
  if (value < minimum) {
    throw B02ValidationException('$field must be at least $minimum.');
  }
}

void _contiguousOrdinals(Iterable<int> ordinals, String field) {
  final sorted = [...ordinals]..sort();
  for (var index = 0; index < sorted.length; index++) {
    if (sorted[index] != index) {
      throw B02ValidationException(
        '$field ordinals must be contiguous from 0.',
      );
    }
  }
}

class B02ExerciseGroupMember {
  final String id;
  final String exercisePrescriptionId;
  final int ordinal;
  final int? transitionRestSeconds;

  B02ExerciseGroupMember({
    required this.id,
    required this.exercisePrescriptionId,
    required this.ordinal,
    this.transitionRestSeconds,
  }) {
    _requiredString(id, 'member id');
    _requiredString(exercisePrescriptionId, 'exercise prescription id');
    if (ordinal < 0) throw B02ValidationException('Member ordinal is invalid.');
    _nonNegative(transitionRestSeconds, 'transition rest');
  }

  factory B02ExerciseGroupMember.fromJson(Map<String, dynamic> json) {
    return B02ExerciseGroupMember(
      id: _requiredString(json['id'], 'member id'),
      exercisePrescriptionId: _requiredString(
        json['exercisePrescriptionId'],
        'exercise prescription id',
      ),
      ordinal: _requiredInt(json['ordinal'], 'member ordinal'),
      transitionRestSeconds: _optionalInt(
        json['transitionRestSeconds'],
        'transition rest',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercisePrescriptionId': exercisePrescriptionId,
    'ordinal': ordinal,
    if (transitionRestSeconds != null)
      'transitionRestSeconds': transitionRestSeconds,
  };
}

class B02ExerciseGroup {
  final String id;
  final String? sessionTemplateId;
  final int ordinal;
  final B02GroupType groupType;
  final int roundCount;
  final int? restAfterRoundSeconds;
  final String? label;
  final List<B02ExerciseGroupMember> members;

  B02ExerciseGroup({
    required this.id,
    this.sessionTemplateId,
    required this.ordinal,
    required this.groupType,
    required this.roundCount,
    this.restAfterRoundSeconds,
    this.label,
    required this.members,
  }) {
    _requiredString(id, 'group id');
    if (sessionTemplateId != null) {
      _requiredString(sessionTemplateId, 'session template id');
    }
    if (ordinal < 0) throw B02ValidationException('Group ordinal is invalid.');
    _atLeast(roundCount, 1, 'round count');
    _nonNegative(restAfterRoundSeconds, 'group rest');
    if (!groupType.acceptsMemberCount(members.length)) {
      throw B02ValidationException(
        '${groupType.dbValue} requires a valid member count; got ${members.length}.',
      );
    }
    _contiguousOrdinals(members.map((member) => member.ordinal), 'Member');
    final prescriptionIds = <String>{};
    for (final member in members) {
      if (!prescriptionIds.add(member.exercisePrescriptionId)) {
        throw B02ValidationException(
          'A prescription cannot occur twice in one group.',
        );
      }
    }
  }

  factory B02ExerciseGroup.fromJson(Map<String, dynamic> json) {
    final members = _list(json['members'], 'group members')
        .map((raw) => B02ExerciseGroupMember.fromJson(_object(raw, 'member')))
        .toList(growable: false);
    return B02ExerciseGroup(
      id: _requiredString(json['id'], 'group id'),
      sessionTemplateId: _optionalString(
        json['sessionTemplateId'],
        'session template id',
      ),
      ordinal: _requiredInt(json['ordinal'], 'group ordinal'),
      groupType: B02GroupType.parse(json['groupType']),
      roundCount: _requiredInt(json['roundCount'], 'round count'),
      restAfterRoundSeconds: _optionalInt(
        json['restAfterRoundSeconds'],
        'group rest',
      ),
      label: _optionalString(json['label'], 'group label'),
      members: members,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (sessionTemplateId != null) 'sessionTemplateId': sessionTemplateId,
    'ordinal': ordinal,
    'groupType': groupType.dbValue,
    'roundCount': roundCount,
    if (restAfterRoundSeconds != null)
      'restAfterRoundSeconds': restAfterRoundSeconds,
    if (label != null) 'label': label,
    'members': members.map((member) => member.toJson()).toList(),
  };
}

class B02SetSegment {
  final String? id;
  final int ordinal;
  final int reps;
  final double? externalLoadKg;
  final B02LoadBasis? loadBasis;
  final double? assistanceKg;
  final int? restBeforeSeconds;

  B02SetSegment({
    this.id,
    required this.ordinal,
    required this.reps,
    this.externalLoadKg,
    this.loadBasis,
    this.assistanceKg,
    this.restBeforeSeconds,
  }) {
    if (id != null) _requiredString(id, 'segment id');
    if (ordinal < 0) {
      throw B02ValidationException('Segment ordinal is invalid.');
    }
    _atLeast(reps, 1, 'segment reps');
    _nonNegative(externalLoadKg, 'segment external load');
    _positive(assistanceKg, 'segment assistance');
    _nonNegative(restBeforeSeconds, 'segment rest');
    if (loadBasis == B02LoadBasis.bodyweight && externalLoadKg != null) {
      throw B02ValidationException(
        'Bodyweight segments cannot carry an external load.',
      );
    }
  }

  factory B02SetSegment.fromJson(Map<String, dynamic> json) {
    return B02SetSegment(
      id: _optionalString(json['id'], 'segment id'),
      ordinal: _requiredInt(json['ordinal'], 'segment ordinal'),
      reps: _requiredInt(json['reps'], 'segment reps'),
      externalLoadKg: _optionalDouble(
        json['externalLoadKg'],
        'segment external load',
      ),
      loadBasis: json['loadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['loadBasis']),
      assistanceKg: _optionalDouble(json['assistanceKg'], 'segment assistance'),
      restBeforeSeconds: _optionalInt(
        json['restBeforeSeconds'],
        'segment rest',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'ordinal': ordinal,
    'reps': reps,
    if (externalLoadKg != null) 'externalLoadKg': externalLoadKg,
    if (loadBasis != null) 'loadBasis': loadBasis!.dbValue,
    if (assistanceKg != null) 'assistanceKg': assistanceKg,
    if (restBeforeSeconds != null) 'restBeforeSeconds': restBeforeSeconds,
  };
}

class B02TechniqueFields {
  final B02EffortMode effortMode;
  final bool endedAtFailure;
  final bool isDropSet;
  final bool isRestPause;
  final int? tempoEccentricSeconds;
  final int? tempoBottomPauseSeconds;
  final int? tempoConcentricSeconds;
  final int? tempoLockoutPauseSeconds;
  final B02PausedRepPosition? pausedRepPosition;
  final int? pausedRepSeconds;
  final B02AssistanceMode? assistanceMode;
  final double? assistanceKg;
  final List<B02SetSegment> segments;

  B02TechniqueFields({
    this.effortMode = B02EffortMode.standard,
    this.endedAtFailure = false,
    this.isDropSet = false,
    this.isRestPause = false,
    this.tempoEccentricSeconds,
    this.tempoBottomPauseSeconds,
    this.tempoConcentricSeconds,
    this.tempoLockoutPauseSeconds,
    this.pausedRepPosition,
    this.pausedRepSeconds,
    this.assistanceMode,
    this.assistanceKg,
    this.segments = const [],
  }) {
    final tempo = [
      tempoEccentricSeconds,
      tempoBottomPauseSeconds,
      tempoConcentricSeconds,
      tempoLockoutPauseSeconds,
    ];
    final hasTempo = tempo.any((value) => value != null);
    if (hasTempo && tempo.any((value) => value == null)) {
      throw B02ValidationException(
        'Tempo requires eccentric, bottom pause, concentric and lockout pause values.',
      );
    }
    if (hasTempo) {
      for (final value in tempo) {
        _nonNegative(value, 'tempo component');
      }
      if (tempo.every((value) => value == 0)) {
        throw B02ValidationException('Tempo cannot contain four zero values.');
      }
    }
    if ((pausedRepPosition == null) != (pausedRepSeconds == null)) {
      throw B02ValidationException(
        'Paused reps require both position and duration.',
      );
    }
    _positive(pausedRepSeconds, 'paused-rep duration');
    if ((assistanceMode == null) != (assistanceKg == null)) {
      throw B02ValidationException(
        'Assisted reps require both assistance mode and assistance load.',
      );
    }
    _positive(assistanceKg, 'assistance load');
    _contiguousOrdinals(segments.map((segment) => segment.ordinal), 'Segment');
    if (segments.isNotEmpty && !isDropSet && !isRestPause) {
      throw const B02ValidationException(
        'Segments require drop-set or rest-pause intent.',
      );
    }
    if (isDropSet && segments.length < 2) {
      throw B02ValidationException('Drop sets require at least two segments.');
    }
    if (isRestPause && segments.length < 2) {
      throw B02ValidationException(
        'Rest-pause sets require at least two segments.',
      );
    }
    if (isDropSet && !_hasLoadDrop(segments)) {
      throw B02ValidationException(
        'Drop sets require a lower external load in a later segment.',
      );
    }
    if (isRestPause &&
        segments
            .skip(1)
            .any((segment) => (segment.restBeforeSeconds ?? 0) <= 0)) {
      throw B02ValidationException(
        'Rest-pause segments require positive rest before each later cluster.',
      );
    }
  }

  static bool _hasLoadDrop(List<B02SetSegment> segments) {
    final loads = segments.map((segment) => segment.externalLoadKg).toList();
    if (loads.any((load) => load == null)) return false;
    for (var index = 1; index < loads.length; index++) {
      if (loads[index]! < loads[index - 1]!) return true;
    }
    return false;
  }

  factory B02TechniqueFields.fromJson(Map<String, dynamic> json) {
    final segments = _list(json['segments'] ?? const [], 'segments')
        .map((raw) => B02SetSegment.fromJson(_object(raw, 'segment')))
        .toList(growable: false);
    return B02TechniqueFields(
      effortMode: json['effortMode'] == null
          ? B02EffortMode.standard
          : B02EffortMode.parse(json['effortMode']),
      endedAtFailure: json['endedAtFailure'] == null
          ? false
          : _requiredBool(json['endedAtFailure'], 'ended at failure'),
      isDropSet: json['isDropSet'] == null
          ? false
          : _requiredBool(json['isDropSet'], 'drop set'),
      isRestPause: json['isRestPause'] == null
          ? false
          : _requiredBool(json['isRestPause'], 'rest pause'),
      tempoEccentricSeconds: _optionalInt(
        json['tempoEccentricSeconds'],
        'tempo eccentric',
      ),
      tempoBottomPauseSeconds: _optionalInt(
        json['tempoBottomPauseSeconds'],
        'tempo bottom pause',
      ),
      tempoConcentricSeconds: _optionalInt(
        json['tempoConcentricSeconds'],
        'tempo concentric',
      ),
      tempoLockoutPauseSeconds: _optionalInt(
        json['tempoLockoutPauseSeconds'],
        'tempo lockout pause',
      ),
      pausedRepPosition: json['pausedRepPosition'] == null
          ? null
          : B02PausedRepPosition.parse(json['pausedRepPosition']),
      pausedRepSeconds: _optionalInt(
        json['pausedRepSeconds'],
        'paused-rep seconds',
      ),
      assistanceMode: json['assistanceMode'] == null
          ? null
          : B02AssistanceMode.parse(json['assistanceMode']),
      assistanceKg: _optionalDouble(json['assistanceKg'], 'assistance load'),
      segments: segments,
    );
  }

  Map<String, dynamic> toJson() => {
    'effortMode': effortMode.dbValue,
    'endedAtFailure': endedAtFailure,
    'isDropSet': isDropSet,
    'isRestPause': isRestPause,
    if (tempoEccentricSeconds != null)
      'tempoEccentricSeconds': tempoEccentricSeconds,
    if (tempoBottomPauseSeconds != null)
      'tempoBottomPauseSeconds': tempoBottomPauseSeconds,
    if (tempoConcentricSeconds != null)
      'tempoConcentricSeconds': tempoConcentricSeconds,
    if (tempoLockoutPauseSeconds != null)
      'tempoLockoutPauseSeconds': tempoLockoutPauseSeconds,
    if (pausedRepPosition != null)
      'pausedRepPosition': pausedRepPosition!.dbValue,
    if (pausedRepSeconds != null) 'pausedRepSeconds': pausedRepSeconds,
    if (assistanceMode != null) 'assistanceMode': assistanceMode!.dbValue,
    if (assistanceKg != null) 'assistanceKg': assistanceKg,
    'segments': segments.map((segment) => segment.toJson()).toList(),
  };
}

class B02StrengthSetPrescription {
  final String id;
  final String exercisePrescriptionId;
  final int ordinal;
  final double? targetLoadKg;
  final B02LoadBasis? loadBasis;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? targetRpe;
  final int? restSeconds;
  final B02TechniqueFields technique;

  B02StrengthSetPrescription({
    required this.id,
    required this.exercisePrescriptionId,
    required this.ordinal,
    this.targetLoadKg,
    this.loadBasis,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetRpe,
    this.restSeconds,
    B02TechniqueFields? technique,
  }) : technique = technique ?? B02TechniqueFields() {
    _requiredString(id, 'strength prescription id');
    _requiredString(exercisePrescriptionId, 'exercise prescription id');
    if (ordinal < 0) throw B02ValidationException('Set ordinal is invalid.');
    _nonNegative(targetLoadKg, 'target load');
    _atLeast(targetRepsMin ?? 1, 1, 'target minimum reps');
    _atLeast(targetRepsMax ?? 1, 1, 'target maximum reps');
    final minReps = targetRepsMin;
    final maxReps = targetRepsMax;
    final rpe = targetRpe;
    if (minReps != null && maxReps != null && minReps > maxReps) {
      throw B02ValidationException('Target minimum reps exceed maximum reps.');
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      throw B02ValidationException('Target RPE must be between 1 and 10.');
    }
    _nonNegative(restSeconds, 'prescribed rest');
  }

  factory B02StrengthSetPrescription.fromJson(Map<String, dynamic> json) {
    return B02StrengthSetPrescription(
      id: _requiredString(json['id'], 'strength prescription id'),
      exercisePrescriptionId: _requiredString(
        json['exercisePrescriptionId'],
        'exercise prescription id',
      ),
      ordinal: _requiredInt(json['ordinal'], 'set ordinal'),
      targetLoadKg: _optionalDouble(json['targetLoadKg'], 'target load'),
      loadBasis: json['loadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['loadBasis']),
      targetRepsMin: _optionalInt(json['targetRepsMin'], 'target minimum reps'),
      targetRepsMax: _optionalInt(json['targetRepsMax'], 'target maximum reps'),
      targetRpe: _optionalInt(json['targetRpe'], 'target RPE'),
      restSeconds: _optionalInt(json['restSeconds'], 'prescribed rest'),
      technique: B02TechniqueFields.fromJson(
        _object(json['technique'] ?? const {}, 'technique'),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercisePrescriptionId': exercisePrescriptionId,
    'ordinal': ordinal,
    if (targetLoadKg != null) 'targetLoadKg': targetLoadKg,
    if (loadBasis != null) 'loadBasis': loadBasis!.dbValue,
    if (targetRepsMin != null) 'targetRepsMin': targetRepsMin,
    if (targetRepsMax != null) 'targetRepsMax': targetRepsMax,
    if (targetRpe != null) 'targetRpe': targetRpe,
    if (restSeconds != null) 'restSeconds': restSeconds,
    'technique': technique.toJson(),
  };
}

class B02PerformedSet {
  final String id;
  final String performedExerciseId;
  final int ordinal;
  final B02SetRole role;
  final double? targetLoadKg;
  final B02LoadBasis? targetLoadBasis;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? targetRpe;
  final double? actualLoadKg;
  final B02LoadBasis? actualLoadBasis;
  final int? actualReps;
  final int? actualRpe;
  final B02TechniqueFields technique;
  final String? notes;

  B02PerformedSet({
    required this.id,
    required this.performedExerciseId,
    required this.ordinal,
    required this.role,
    this.targetLoadKg,
    this.targetLoadBasis,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetRpe,
    this.actualLoadKg,
    this.actualLoadBasis,
    this.actualReps,
    this.actualRpe,
    B02TechniqueFields? technique,
    this.notes,
  }) : technique = technique ?? B02TechniqueFields() {
    _requiredString(id, 'performed set id');
    _requiredString(performedExerciseId, 'performed exercise id');
    if (ordinal < 0) {
      throw B02ValidationException('Performed set ordinal is invalid.');
    }
    _nonNegative(targetLoadKg, 'target load');
    _nonNegative(actualLoadKg, 'actual load');
    _nonNegative(actualReps, 'actual reps');
    final minReps = targetRepsMin;
    final maxReps = targetRepsMax;
    final targetRpeValue = targetRpe;
    final actualRpeValue = actualRpe;
    if (minReps != null && minReps < 1) {
      throw B02ValidationException('Target minimum reps must be positive.');
    }
    if (maxReps != null && maxReps < 1) {
      throw B02ValidationException('Target maximum reps must be positive.');
    }
    if (minReps != null && maxReps != null && minReps > maxReps) {
      throw B02ValidationException('Target minimum reps exceed maximum reps.');
    }
    if (targetRpeValue != null && (targetRpeValue < 1 || targetRpeValue > 10)) {
      throw B02ValidationException('Target RPE must be between 1 and 10.');
    }
    if (actualRpeValue != null && (actualRpeValue < 1 || actualRpeValue > 10)) {
      throw B02ValidationException('Actual RPE must be between 1 and 10.');
    }
    if (this.technique.segments.isNotEmpty && actualReps != null) {
      final segmentReps = this.technique.segments.fold<int>(
        0,
        (sum, segment) => sum + segment.reps,
      );
      if (segmentReps != actualReps) {
        throw B02ValidationException(
          'Performed segment reps must equal the set actual reps.',
        );
      }
    }
  }

  factory B02PerformedSet.fromJson(Map<String, dynamic> json) {
    return B02PerformedSet(
      id: _requiredString(json['id'], 'performed set id'),
      performedExerciseId: _requiredString(
        json['performedExerciseId'],
        'performed exercise id',
      ),
      ordinal: _requiredInt(json['ordinal'], 'performed set ordinal'),
      role: B02SetRole.parse(json['role']),
      targetLoadKg: _optionalDouble(json['targetLoadKg'], 'target load'),
      targetLoadBasis: json['targetLoadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['targetLoadBasis']),
      targetRepsMin: _optionalInt(json['targetRepsMin'], 'target minimum reps'),
      targetRepsMax: _optionalInt(json['targetRepsMax'], 'target maximum reps'),
      targetRpe: _optionalInt(json['targetRpe'], 'target RPE'),
      actualLoadKg: _optionalDouble(json['actualLoadKg'], 'actual load'),
      actualLoadBasis: json['actualLoadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['actualLoadBasis']),
      actualReps: _optionalInt(json['actualReps'], 'actual reps'),
      actualRpe: _optionalInt(json['actualRpe'], 'actual RPE'),
      technique: B02TechniqueFields.fromJson(
        _object(json['technique'] ?? const {}, 'technique'),
      ),
      notes: _optionalString(json['notes'], 'set notes'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'performedExerciseId': performedExerciseId,
    'ordinal': ordinal,
    'role': role.dbValue,
    if (targetLoadKg != null) 'targetLoadKg': targetLoadKg,
    if (targetLoadBasis != null) 'targetLoadBasis': targetLoadBasis!.dbValue,
    if (targetRepsMin != null) 'targetRepsMin': targetRepsMin,
    if (targetRepsMax != null) 'targetRepsMax': targetRepsMax,
    if (targetRpe != null) 'targetRpe': targetRpe,
    if (actualLoadKg != null) 'actualLoadKg': actualLoadKg,
    if (actualLoadBasis != null) 'actualLoadBasis': actualLoadBasis!.dbValue,
    if (actualReps != null) 'actualReps': actualReps,
    if (actualRpe != null) 'actualRpe': actualRpe,
    'technique': technique.toJson(),
    if (notes != null) 'notes': notes,
  };
}

class B02TargetRecommendation {
  final String id;
  final String performedExerciseId;
  final String ruleVersion;
  final B02Confidence confidence;
  final Map<String, dynamic> completeness;
  final double? recommendedLoadKg;
  final B02LoadBasis? loadBasis;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? targetRpe;
  final double? incrementKg;
  final DateTime? evidenceCutoffUtc;
  final int comparatorCount;
  final List<String> rationaleCodes;
  final bool wasOverridden;

  B02TargetRecommendation({
    required this.id,
    required this.performedExerciseId,
    required this.ruleVersion,
    required this.confidence,
    required this.completeness,
    this.recommendedLoadKg,
    this.loadBasis,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetRpe,
    this.incrementKg,
    this.evidenceCutoffUtc,
    this.comparatorCount = 0,
    required this.rationaleCodes,
    this.wasOverridden = false,
  }) {
    _requiredString(id, 'recommendation id');
    _requiredString(performedExerciseId, 'performed exercise id');
    _requiredString(ruleVersion, 'recommendation rule version');
    _nonNegative(recommendedLoadKg, 'recommended load');
    _positive(incrementKg, 'equipment increment');
    final minReps = targetRepsMin;
    final maxReps = targetRepsMax;
    final rpe = targetRpe;
    if (minReps != null && minReps < 1) {
      throw B02ValidationException('Target minimum reps must be positive.');
    }
    if (maxReps != null && maxReps < 1) {
      throw B02ValidationException('Target maximum reps must be positive.');
    }
    if (minReps != null && maxReps != null && minReps > maxReps) {
      throw B02ValidationException('Target minimum reps exceed maximum reps.');
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      throw B02ValidationException('Target RPE must be between 1 and 10.');
    }
    if (comparatorCount < 0) {
      throw B02ValidationException('Comparator count cannot be negative.');
    }
    if (rationaleCodes.any((code) => code.trim().isEmpty)) {
      throw B02ValidationException('Rationale codes cannot be blank.');
    }
  }

  factory B02TargetRecommendation.fromJson(Map<String, dynamic> json) {
    final rationale =
        _list(json['rationaleCodes'] ?? const [], 'rationale codes')
            .map((raw) => _requiredString(raw, 'rationale code'))
            .toList(growable: false);
    final completenessRaw = _object(
      json['completeness'] ?? const {},
      'recommendation completeness',
    );
    return B02TargetRecommendation(
      id: _requiredString(json['id'], 'recommendation id'),
      performedExerciseId: _requiredString(
        json['performedExerciseId'],
        'performed exercise id',
      ),
      ruleVersion: _requiredString(json['ruleVersion'], 'rule version'),
      confidence: B02Confidence.parse(json['confidence']),
      completeness: completenessRaw,
      recommendedLoadKg: _optionalDouble(
        json['recommendedLoadKg'],
        'recommended load',
      ),
      loadBasis: json['loadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['loadBasis']),
      targetRepsMin: _optionalInt(json['targetRepsMin'], 'target minimum reps'),
      targetRepsMax: _optionalInt(json['targetRepsMax'], 'target maximum reps'),
      targetRpe: _optionalInt(json['targetRpe'], 'target RPE'),
      incrementKg: _optionalDouble(json['incrementKg'], 'equipment increment'),
      evidenceCutoffUtc: json['evidenceCutoffUtc'] == null
          ? null
          : DateTime.tryParse(
                  _requiredString(json['evidenceCutoffUtc'], 'evidence cutoff'),
                )?.toUtc() ??
                (throw const B02ValidationException(
                  'Evidence cutoff must be an ISO-8601 date.',
                )),
      comparatorCount: json['comparatorCount'] == null
          ? 0
          : _requiredInt(json['comparatorCount'], 'comparator count'),
      rationaleCodes: rationale,
      wasOverridden: json['wasOverridden'] == null
          ? false
          : _requiredBool(json['wasOverridden'], 'recommendation override'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'performedExerciseId': performedExerciseId,
    'ruleVersion': ruleVersion,
    'confidence': confidence.dbValue,
    'completeness': completeness,
    if (recommendedLoadKg != null) 'recommendedLoadKg': recommendedLoadKg,
    if (loadBasis != null) 'loadBasis': loadBasis!.dbValue,
    if (targetRepsMin != null) 'targetRepsMin': targetRepsMin,
    if (targetRepsMax != null) 'targetRepsMax': targetRepsMax,
    if (targetRpe != null) 'targetRpe': targetRpe,
    if (incrementKg != null) 'incrementKg': incrementKg,
    if (evidenceCutoffUtc != null)
      'evidenceCutoffUtc': evidenceCutoffUtc!.toUtc().toIso8601String(),
    'comparatorCount': comparatorCount,
    'rationaleCodes': rationaleCodes,
    'wasOverridden': wasOverridden,
  };

  B02TargetRecommendation copyWith({
    String? id,
    String? performedExerciseId,
    bool? wasOverridden,
  }) {
    return B02TargetRecommendation(
      id: id ?? this.id,
      performedExerciseId: performedExerciseId ?? this.performedExerciseId,
      ruleVersion: ruleVersion,
      confidence: confidence,
      completeness: completeness,
      recommendedLoadKg: recommendedLoadKg,
      loadBasis: loadBasis,
      targetRepsMin: targetRepsMin,
      targetRepsMax: targetRepsMax,
      targetRpe: targetRpe,
      incrementKg: incrementKg,
      evidenceCutoffUtc: evidenceCutoffUtc,
      comparatorCount: comparatorCount,
      rationaleCodes: rationaleCodes,
      wasOverridden: wasOverridden ?? this.wasOverridden,
    );
  }
}

class B02RestPeriod {
  final String id;
  final String? performedSetId;
  final String? performedExerciseGroupId;
  final B02RestScope scope;
  final int? recommendedSeconds;
  final int? selectedSeconds;
  final int? actualSeconds;
  final B02RestSource source;
  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;
  final B02RestEndReason? endReason;

  B02RestPeriod({
    required this.id,
    this.performedSetId,
    this.performedExerciseGroupId,
    required this.scope,
    this.recommendedSeconds,
    this.selectedSeconds,
    this.actualSeconds,
    required this.source,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.endReason,
  }) {
    _requiredString(id, 'rest period id');
    if (performedSetId == null && performedExerciseGroupId == null) {
      throw B02ValidationException(
        'A rest period needs a performed set or group parent.',
      );
    }
    _nonNegative(recommendedSeconds, 'recommended rest');
    _nonNegative(selectedSeconds, 'selected rest');
    _nonNegative(actualSeconds, 'actual rest');
    if (endedAtUtc != null && endedAtUtc!.isBefore(startedAtUtc)) {
      throw B02ValidationException('Rest end cannot precede rest start.');
    }
    if (endedAtUtc == null && (actualSeconds != null || endReason != null)) {
      throw B02ValidationException(
        'An open rest period cannot have an end result.',
      );
    }
  }

  factory B02RestPeriod.fromJson(Map<String, dynamic> json) {
    final started = DateTime.tryParse(
      _requiredString(json['startedAtUtc'], 'rest start'),
    );
    if (started == null) {
      throw const B02ValidationException(
        'Rest start must be an ISO-8601 date.',
      );
    }
    final endedRaw = json['endedAtUtc'];
    final ended = endedRaw == null
        ? null
        : DateTime.tryParse(_requiredString(endedRaw, 'rest end'));
    if (endedRaw != null && ended == null) {
      throw const B02ValidationException('Rest end must be an ISO-8601 date.');
    }
    return B02RestPeriod(
      id: _requiredString(json['id'], 'rest period id'),
      performedSetId: _optionalString(
        json['performedSetId'],
        'performed set id',
      ),
      performedExerciseGroupId: _optionalString(
        json['performedExerciseGroupId'],
        'performed exercise group id',
      ),
      scope: B02RestScope.parse(json['scope']),
      recommendedSeconds: _optionalInt(
        json['recommendedSeconds'],
        'recommended rest',
      ),
      selectedSeconds: _optionalInt(json['selectedSeconds'], 'selected rest'),
      actualSeconds: _optionalInt(json['actualSeconds'], 'actual rest'),
      source: B02RestSource.parse(json['source']),
      startedAtUtc: started.toUtc(),
      endedAtUtc: ended?.toUtc(),
      endReason: json['endReason'] == null
          ? null
          : B02RestEndReason.parse(json['endReason']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (performedSetId != null) 'performedSetId': performedSetId,
    if (performedExerciseGroupId != null)
      'performedExerciseGroupId': performedExerciseGroupId,
    'scope': scope.dbValue,
    if (recommendedSeconds != null) 'recommendedSeconds': recommendedSeconds,
    if (selectedSeconds != null) 'selectedSeconds': selectedSeconds,
    if (actualSeconds != null) 'actualSeconds': actualSeconds,
    'source': source.dbValue,
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    if (endedAtUtc != null) 'endedAtUtc': endedAtUtc!.toUtc().toIso8601String(),
    if (endReason != null) 'endReason': endReason!.dbValue,
  };
}

class B02CardioInterval {
  final String id;
  final int ordinal;
  final B02CardioSegmentType segmentType;
  final int? durationSeconds;
  final int? distanceMetres;
  final double? targetPaceSecondsPerKm;
  final double? actualPaceSecondsPerKm;
  final String? targetIntensity;
  final String? actualIntensity;
  final int? averageHeartRate;

  B02CardioInterval({
    required this.id,
    required this.ordinal,
    required this.segmentType,
    this.durationSeconds,
    this.distanceMetres,
    this.targetPaceSecondsPerKm,
    this.actualPaceSecondsPerKm,
    this.targetIntensity,
    this.actualIntensity,
    this.averageHeartRate,
  }) {
    _requiredString(id, 'cardio interval id');
    if (ordinal < 0) {
      throw B02ValidationException('Interval ordinal is invalid.');
    }
    if (durationSeconds == null && distanceMetres == null) {
      throw B02ValidationException(
        'A cardio interval needs duration or distance.',
      );
    }
    _positive(durationSeconds, 'interval duration');
    _positive(distanceMetres, 'interval distance');
    _positive(targetPaceSecondsPerKm, 'target pace');
    _positive(actualPaceSecondsPerKm, 'actual pace');
    _positive(averageHeartRate, 'interval average heart rate');
    _optionalString(targetIntensity, 'target intensity');
    _optionalString(actualIntensity, 'actual intensity');
  }

  factory B02CardioInterval.fromJson(Map<String, dynamic> json) {
    return B02CardioInterval(
      id: _requiredString(json['id'], 'cardio interval id'),
      ordinal: _requiredInt(json['ordinal'], 'interval ordinal'),
      segmentType: B02CardioSegmentType.parse(json['segmentType']),
      durationSeconds: _optionalInt(
        json['durationSeconds'],
        'interval duration',
      ),
      distanceMetres: _optionalInt(json['distanceMetres'], 'interval distance'),
      targetPaceSecondsPerKm: _optionalDouble(
        json['targetPaceSecondsPerKm'],
        'target pace',
      ),
      actualPaceSecondsPerKm: _optionalDouble(
        json['actualPaceSecondsPerKm'],
        'actual pace',
      ),
      targetIntensity: _optionalString(
        json['targetIntensity'],
        'target intensity',
      ),
      actualIntensity: _optionalString(
        json['actualIntensity'],
        'actual intensity',
      ),
      averageHeartRate: _optionalInt(
        json['averageHeartRate'],
        'interval average heart rate',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ordinal': ordinal,
    'segmentType': segmentType.dbValue,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (distanceMetres != null) 'distanceMetres': distanceMetres,
    if (targetPaceSecondsPerKm != null)
      'targetPaceSecondsPerKm': targetPaceSecondsPerKm,
    if (actualPaceSecondsPerKm != null)
      'actualPaceSecondsPerKm': actualPaceSecondsPerKm,
    if (targetIntensity != null) 'targetIntensity': targetIntensity,
    if (actualIntensity != null) 'actualIntensity': actualIntensity,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
  };
}

class B02CardioSessionDetail {
  final B02ActivityType activityType;
  final int durationSeconds;
  final int? distanceMetres;
  final double? observedPaceSecondsPerKm;
  final double? observedSpeedKph;
  final double? inclinePercentage;
  final double? elevationMetres;
  final int? averageHeartRate;
  final int? perceivedExertion;
  final bool isIntervalWorkout;
  final B02InputMode inputMode;
  final List<B02CardioInterval> intervals;

  B02CardioSessionDetail({
    required this.activityType,
    required this.durationSeconds,
    this.distanceMetres,
    this.observedPaceSecondsPerKm,
    this.observedSpeedKph,
    this.inclinePercentage,
    this.elevationMetres,
    this.averageHeartRate,
    this.perceivedExertion,
    this.isIntervalWorkout = false,
    required this.inputMode,
    this.intervals = const [],
  }) {
    if (![
      B02ActivityType.running,
      B02ActivityType.cycling,
      B02ActivityType.walking,
    ].contains(activityType)) {
      throw B02ValidationException(
        'Cardio detail requires running, cycling or walking activity type.',
      );
    }
    _positive(durationSeconds, 'cardio duration');
    _positive(distanceMetres, 'cardio distance');
    _positive(observedPaceSecondsPerKm, 'observed pace');
    _positive(observedSpeedKph, 'observed speed');
    _nonNegative(inclinePercentage, 'incline');
    _nonNegative(elevationMetres, 'elevation');
    _positive(averageHeartRate, 'average heart rate');
    final perceivedExertionValue = perceivedExertion;
    if (perceivedExertionValue != null &&
        (perceivedExertionValue < 1 || perceivedExertionValue > 10)) {
      throw B02ValidationException(
        'Perceived exertion must be between 1 and 10.',
      );
    }
    _contiguousOrdinals(
      intervals.map((interval) => interval.ordinal),
      'Interval',
    );
    if (isIntervalWorkout &&
        intervals
            .where(
              (interval) => interval.segmentType == B02CardioSegmentType.work,
            )
            .isEmpty) {
      throw B02ValidationException(
        'Interval cardio requires at least one work interval.',
      );
    }
  }

  factory B02CardioSessionDetail.fromJson(Map<String, dynamic> json) {
    final intervals = _list(json['intervals'] ?? const [], 'cardio intervals')
        .map(
          (raw) => B02CardioInterval.fromJson(_object(raw, 'cardio interval')),
        )
        .toList(growable: false);
    return B02CardioSessionDetail(
      activityType: B02ActivityType.parse(json['activityType']),
      durationSeconds: _requiredInt(json['durationSeconds'], 'cardio duration'),
      distanceMetres: _optionalInt(json['distanceMetres'], 'cardio distance'),
      observedPaceSecondsPerKm: _optionalDouble(
        json['observedPaceSecondsPerKm'],
        'observed pace',
      ),
      observedSpeedKph: _optionalDouble(
        json['observedSpeedKph'],
        'observed speed',
      ),
      inclinePercentage: _optionalDouble(json['inclinePercentage'], 'incline'),
      elevationMetres: _optionalDouble(json['elevationMetres'], 'elevation'),
      averageHeartRate: _optionalInt(
        json['averageHeartRate'],
        'average heart rate',
      ),
      perceivedExertion: _optionalInt(
        json['perceivedExertion'],
        'perceived exertion',
      ),
      isIntervalWorkout: json['isIntervalWorkout'] == null
          ? false
          : _requiredBool(json['isIntervalWorkout'], 'interval workout'),
      inputMode: B02InputMode.parse(json['inputMode']),
      intervals: intervals,
    );
  }

  Map<String, dynamic> toJson() => {
    'activityType': activityType.dbValue,
    'durationSeconds': durationSeconds,
    if (distanceMetres != null) 'distanceMetres': distanceMetres,
    if (observedPaceSecondsPerKm != null)
      'observedPaceSecondsPerKm': observedPaceSecondsPerKm,
    if (observedSpeedKph != null) 'observedSpeedKph': observedSpeedKph,
    if (inclinePercentage != null) 'inclinePercentage': inclinePercentage,
    if (elevationMetres != null) 'elevationMetres': elevationMetres,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (perceivedExertion != null) 'perceivedExertion': perceivedExertion,
    'isIntervalWorkout': isIntervalWorkout,
    'inputMode': inputMode.dbValue,
    'intervals': intervals.map((interval) => interval.toJson()).toList(),
  };
}

class B02MobilitySessionDetail {
  final B02ActivityType practiceType;
  final int durationSeconds;
  final String? style;
  final String? intensity;
  final String? focusNote;
  final int? averageHeartRate;

  B02MobilitySessionDetail({
    required this.practiceType,
    required this.durationSeconds,
    this.style,
    this.intensity,
    this.focusNote,
    this.averageHeartRate,
  }) {
    if (![
      B02ActivityType.yoga,
      B02ActivityType.mobility,
    ].contains(practiceType)) {
      throw B02ValidationException(
        'Mobility detail requires yoga or mobility activity type.',
      );
    }
    _positive(durationSeconds, 'mobility duration');
    _optionalString(style, 'mobility style');
    _optionalString(intensity, 'mobility intensity');
    _optionalString(focusNote, 'mobility focus note');
    _positive(averageHeartRate, 'average heart rate');
  }

  factory B02MobilitySessionDetail.fromJson(Map<String, dynamic> json) {
    return B02MobilitySessionDetail(
      practiceType: B02ActivityType.parse(json['practiceType']),
      durationSeconds: _requiredInt(
        json['durationSeconds'],
        'mobility duration',
      ),
      style: _optionalString(json['style'], 'mobility style'),
      intensity: _optionalString(json['intensity'], 'mobility intensity'),
      focusNote: _optionalString(json['focusNote'], 'mobility focus note'),
      averageHeartRate: _optionalInt(
        json['averageHeartRate'],
        'average heart rate',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'practiceType': practiceType.dbValue,
    'durationSeconds': durationSeconds,
    if (style != null) 'style': style,
    if (intensity != null) 'intensity': intensity,
    if (focusNote != null) 'focusNote': focusNote,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
  };
}

class B02MuscleContribution {
  final String muscleId;
  final B02MuscleRole role;
  final int contributionBasisPoints;

  B02MuscleContribution({
    required this.muscleId,
    required this.role,
    required this.contributionBasisPoints,
  }) {
    _requiredString(muscleId, 'muscle id');
    if (contributionBasisPoints < 1 || contributionBasisPoints > 10000) {
      throw B02ValidationException(
        'Muscle contribution must be between 1 and 10000 basis points.',
      );
    }
  }

  factory B02MuscleContribution.fromJson(Map<String, dynamic> json) {
    return B02MuscleContribution(
      muscleId: _requiredString(json['muscleId'], 'muscle id'),
      role: B02MuscleRole.parse(json['role']),
      contributionBasisPoints: _requiredInt(
        json['contributionBasisPoints'],
        'contribution basis points',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'muscleId': muscleId,
    'role': role.dbValue,
    'contributionBasisPoints': contributionBasisPoints,
  };
}

class B02ExerciseMuscleMapping {
  final String id;
  final String exerciseId;
  final B02MappingStatus mappingStatus;
  final String? source;
  final int catalogVersion;
  final List<B02MuscleContribution> contributions;

  B02ExerciseMuscleMapping({
    required this.id,
    required this.exerciseId,
    required this.mappingStatus,
    this.source,
    required this.catalogVersion,
    required this.contributions,
  }) {
    _requiredString(id, 'mapping id');
    _requiredString(exerciseId, 'exercise id');
    if (mappingStatus == B02MappingStatus.reviewed && source == null) {
      throw B02ValidationException(
        'Reviewed muscle mappings require a reviewed source.',
      );
    }
    if (source != null) _requiredString(source, 'mapping source');
    _atLeast(catalogVersion, 1, 'catalog version');
    final muscleIds = <String>{};
    for (final contribution in contributions) {
      if (!muscleIds.add(contribution.muscleId)) {
        throw B02ValidationException(
          'A muscle may occur only once in a mapping.',
        );
      }
    }
    final total = contributions.fold<int>(
      0,
      (sum, contribution) => sum + contribution.contributionBasisPoints,
    );
    if (mappingStatus == B02MappingStatus.reviewed && total != 10000) {
      throw B02ValidationException(
        'Reviewed muscle mappings must total 10000 basis points.',
      );
    }
    if (mappingStatus == B02MappingStatus.unknown && contributions.isNotEmpty) {
      throw B02ValidationException(
        'Unknown muscle mappings cannot contain contribution values.',
      );
    }
  }

  factory B02ExerciseMuscleMapping.fromJson(Map<String, dynamic> json) {
    final contributions =
        _list(json['contributions'] ?? const [], 'mapping contributions')
            .map(
              (raw) =>
                  B02MuscleContribution.fromJson(_object(raw, 'contribution')),
            )
            .toList(growable: false);
    return B02ExerciseMuscleMapping(
      id: _requiredString(json['id'], 'mapping id'),
      exerciseId: _requiredString(json['exerciseId'], 'exercise id'),
      mappingStatus: B02MappingStatus.parse(json['mappingStatus']),
      source: _optionalString(json['source'], 'mapping source'),
      catalogVersion: _requiredInt(json['catalogVersion'], 'catalog version'),
      contributions: contributions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'mappingStatus': mappingStatus.dbValue,
    if (source != null) 'source': source,
    'catalogVersion': catalogVersion,
    'contributions': contributions
        .map((contribution) => contribution.toJson())
        .toList(),
  };
}

class B02PerformedExerciseDraft {
  final String id;
  final String? performedExerciseGroupId;
  final String? sourceExercisePrescriptionId;
  final int? groupMemberOrdinal;
  final int? groupRoundOrdinal;
  final int ordinal;
  final String? expectedExerciseId;
  final String? expectedExerciseNameSnapshot;
  final String actualExerciseId;
  final String actualExerciseNameSnapshot;
  final String status;
  final String? substitutionReason;
  final List<B02PerformedSet> sets;
  final B02TargetRecommendation? targetRecommendation;

  B02PerformedExerciseDraft({
    required this.id,
    this.performedExerciseGroupId,
    this.sourceExercisePrescriptionId,
    this.groupMemberOrdinal,
    this.groupRoundOrdinal,
    required this.ordinal,
    this.expectedExerciseId,
    this.expectedExerciseNameSnapshot,
    required this.actualExerciseId,
    required this.actualExerciseNameSnapshot,
    required this.status,
    this.substitutionReason,
    this.sets = const [],
    this.targetRecommendation,
  }) {
    _requiredString(id, 'performed exercise id');
    _requiredString(actualExerciseId, 'actual exercise id');
    _requiredString(actualExerciseNameSnapshot, 'actual exercise snapshot');
    _requiredString(status, 'performed exercise status');
    if (ordinal < 0) {
      throw B02ValidationException('Exercise ordinal is invalid.');
    }
    if (groupMemberOrdinal != null && groupMemberOrdinal! < 0) {
      throw B02ValidationException('Group member ordinal is invalid.');
    }
    if (groupRoundOrdinal != null && groupRoundOrdinal! < 0) {
      throw B02ValidationException('Group round ordinal is invalid.');
    }
    _contiguousOrdinals(sets.map((set) => set.ordinal), 'Performed set');
    if (expectedExerciseId == null && expectedExerciseNameSnapshot != null) {
      _requiredString(
        expectedExerciseNameSnapshot,
        'expected exercise snapshot',
      );
    }
  }

  factory B02PerformedExerciseDraft.fromJson(Map<String, dynamic> json) {
    final sets = _list(json['sets'] ?? const [], 'performed sets')
        .map((raw) => B02PerformedSet.fromJson(_object(raw, 'performed set')))
        .toList(growable: false);
    return B02PerformedExerciseDraft(
      id: _requiredString(json['id'], 'performed exercise id'),
      performedExerciseGroupId: _optionalString(
        json['performedExerciseGroupId'],
        'performed exercise group id',
      ),
      sourceExercisePrescriptionId: _optionalString(
        json['sourceExercisePrescriptionId'],
        'source prescription id',
      ),
      groupMemberOrdinal: _optionalInt(
        json['groupMemberOrdinal'],
        'group member ordinal',
      ),
      groupRoundOrdinal: _optionalInt(
        json['groupRoundOrdinal'],
        'group round ordinal',
      ),
      ordinal: _requiredInt(json['ordinal'], 'performed exercise ordinal'),
      expectedExerciseId: _optionalString(
        json['expectedExerciseId'],
        'expected exercise id',
      ),
      expectedExerciseNameSnapshot: _optionalString(
        json['expectedExerciseNameSnapshot'],
        'expected exercise snapshot',
      ),
      actualExerciseId: _requiredString(
        json['actualExerciseId'],
        'actual exercise id',
      ),
      actualExerciseNameSnapshot: _requiredString(
        json['actualExerciseNameSnapshot'],
        'actual exercise snapshot',
      ),
      status: _requiredString(json['status'], 'performed exercise status'),
      substitutionReason: _optionalString(
        json['substitutionReason'],
        'substitution reason',
      ),
      sets: sets,
      targetRecommendation: json['targetRecommendation'] == null
          ? null
          : B02TargetRecommendation.fromJson(
              _object(json['targetRecommendation'], 'target recommendation'),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (performedExerciseGroupId != null)
      'performedExerciseGroupId': performedExerciseGroupId,
    if (sourceExercisePrescriptionId != null)
      'sourceExercisePrescriptionId': sourceExercisePrescriptionId,
    if (groupMemberOrdinal != null) 'groupMemberOrdinal': groupMemberOrdinal,
    if (groupRoundOrdinal != null) 'groupRoundOrdinal': groupRoundOrdinal,
    'ordinal': ordinal,
    if (expectedExerciseId != null) 'expectedExerciseId': expectedExerciseId,
    if (expectedExerciseNameSnapshot != null)
      'expectedExerciseNameSnapshot': expectedExerciseNameSnapshot,
    'actualExerciseId': actualExerciseId,
    'actualExerciseNameSnapshot': actualExerciseNameSnapshot,
    'status': status,
    if (substitutionReason != null) 'substitutionReason': substitutionReason,
    'sets': sets.map((set) => set.toJson()).toList(),
    if (targetRecommendation != null)
      'targetRecommendation': targetRecommendation!.toJson(),
  };

  B02PerformedExerciseDraft copyWith({
    B02TargetRecommendation? targetRecommendation,
  }) {
    return B02PerformedExerciseDraft(
      id: id,
      performedExerciseGroupId: performedExerciseGroupId,
      sourceExercisePrescriptionId: sourceExercisePrescriptionId,
      groupMemberOrdinal: groupMemberOrdinal,
      groupRoundOrdinal: groupRoundOrdinal,
      ordinal: ordinal,
      expectedExerciseId: expectedExerciseId,
      expectedExerciseNameSnapshot: expectedExerciseNameSnapshot,
      actualExerciseId: actualExerciseId,
      actualExerciseNameSnapshot: actualExerciseNameSnapshot,
      status: status,
      substitutionReason: substitutionReason,
      sets: sets,
      targetRecommendation: targetRecommendation ?? this.targetRecommendation,
    );
  }
}

enum B02WarmupPreference {
  off('off'),
  ask('ask'),
  automatic('automatic');

  final String dbValue;

  const B02WarmupPreference(this.dbValue);

  static B02WarmupPreference parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Warm-up preference must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported warm-up preference "$raw".');
  }
}

enum B02WarmupTargetSource {
  userEditedDraft('userEditedDraft'),
  targetRecommendation('targetRecommendation'),
  prescription('prescription'),
  recentComparable('recentComparable');

  final String dbValue;

  const B02WarmupTargetSource(this.dbValue);

  static B02WarmupTargetSource parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Warm-up target source must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported warm-up target source "$raw".');
  }
}

enum B02WarmupAvailability {
  available('available'),
  unavailable('unavailable');

  final String dbValue;

  const B02WarmupAvailability(this.dbValue);

  static B02WarmupAvailability parse(Object? raw) {
    if (raw is! String) {
      throw B02ValidationException('Warm-up availability must be a string.');
    }
    for (final value in values) {
      if (value.dbValue == raw) return value;
    }
    throw B02ValidationException('Unsupported warm-up availability "$raw".');
  }
}

class B02WarmupLoadCandidate {
  final double? loadKg;
  final B02LoadBasis? loadBasis;
  final B02WarmupTargetSource source;

  const B02WarmupLoadCandidate({
    required this.loadKg,
    required this.loadBasis,
    required this.source,
  });

  factory B02WarmupLoadCandidate.fromJson(Map<String, dynamic> json) {
    return B02WarmupLoadCandidate(
      loadKg: _optionalDouble(json['loadKg'], 'warm-up target load'),
      loadBasis: json['loadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['loadBasis']),
      source: B02WarmupTargetSource.parse(json['source']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (loadKg != null) 'loadKg': loadKg,
    if (loadBasis != null) 'loadBasis': loadBasis!.dbValue,
    'source': source.dbValue,
  };
}

class B02WarmupSetProposal {
  final int ordinal;
  final double? percentageOfWorkingLoad;
  final double? loadKg;
  final B02LoadBasis loadBasis;
  final int reps;
  final bool techniquePreparation;

  B02WarmupSetProposal({
    required this.ordinal,
    this.percentageOfWorkingLoad,
    required this.loadKg,
    required this.loadBasis,
    required this.reps,
    this.techniquePreparation = false,
  }) {
    if (ordinal < 0) {
      throw B02ValidationException('Warm-up proposal ordinal is invalid.');
    }
    _nonNegative(percentageOfWorkingLoad, 'warm-up percentage');
    if (loadBasis == B02LoadBasis.bodyweight) {
      if (loadKg != null) {
        throw B02ValidationException(
          'Bodyweight warm-up proposals cannot carry external load.',
        );
      }
    } else {
      _positive(loadKg, 'warm-up load');
    }
    _atLeast(reps, 1, 'warm-up reps');
    if (techniquePreparation && (reps < 5 || reps > 10)) {
      throw B02ValidationException(
        'Technique-preparation warm-ups must contain 5 to 10 reps.',
      );
    }
  }

  factory B02WarmupSetProposal.fromJson(Map<String, dynamic> json) {
    return B02WarmupSetProposal(
      ordinal: _requiredInt(json['ordinal'], 'warm-up proposal ordinal'),
      percentageOfWorkingLoad: _optionalDouble(
        json['percentageOfWorkingLoad'],
        'warm-up percentage',
      ),
      loadKg: _optionalDouble(json['loadKg'], 'warm-up load'),
      loadBasis: B02LoadBasis.parse(json['loadBasis']),
      reps: _requiredInt(json['reps'], 'warm-up reps'),
      techniquePreparation: json['techniquePreparation'] == null
          ? false
          : _requiredBool(
              json['techniquePreparation'],
              'technique-preparation flag',
            ),
    );
  }

  Map<String, dynamic> toJson() => {
    'ordinal': ordinal,
    if (percentageOfWorkingLoad != null)
      'percentageOfWorkingLoad': percentageOfWorkingLoad,
    if (loadKg != null) 'loadKg': loadKg,
    'loadBasis': loadBasis.dbValue,
    'reps': reps,
    'techniquePreparation': techniquePreparation,
  };
}

class B02WarmupRecommendation {
  static const String ruleVersion = 'b02-warmup-v1';

  final B02WarmupAvailability availability;
  final B02WarmupPreference? preference;
  final B02WarmupTargetSource? selectedSource;
  final B02LoadBasis? loadBasis;
  final double? workingLoadKg;
  final int requestedCount;
  final double? incrementKg;
  final bool incrementUnavailable;
  final String reason;
  final Map<String, bool> completeness;
  final List<B02WarmupSetProposal> proposals;

  B02WarmupRecommendation({
    required this.availability,
    required this.preference,
    required this.selectedSource,
    required this.loadBasis,
    required this.workingLoadKg,
    required this.requestedCount,
    required this.incrementKg,
    required this.incrementUnavailable,
    required this.reason,
    required this.completeness,
    required this.proposals,
  }) {
    if (requestedCount < 1 || requestedCount > 4) {
      throw B02ValidationException(
        'Warm-up request count must be between 1 and 4.',
      );
    }
    _requiredString(reason, 'warm-up reason');
    _nonNegative(workingLoadKg, 'warm-up working load');
    _positive(incrementKg, 'warm-up increment');
    _contiguousOrdinals(
      proposals.map((proposal) => proposal.ordinal),
      'Warm-up proposal',
    );
    if (availability == B02WarmupAvailability.available &&
        selectedSource == null) {
      throw const B02ValidationException(
        'Available warm-up recommendations require a target source.',
      );
    }
    if (loadBasis == B02LoadBasis.bodyweight && workingLoadKg != null) {
      throw const B02ValidationException(
        'Bodyweight warm-up recommendations cannot carry external load.',
      );
    }
  }

  factory B02WarmupRecommendation.fromJson(Map<String, dynamic> json) {
    final version = _requiredString(
      json['ruleVersion'],
      'warm-up rule version',
    );
    if (version != ruleVersion) {
      throw B02ValidationException(
        'Unsupported warm-up rule version "$version".',
      );
    }
    final proposals = _list(json['proposals'] ?? const [], 'warm-up proposals')
        .map(
          (raw) =>
              B02WarmupSetProposal.fromJson(_object(raw, 'warm-up proposal')),
        )
        .toList(growable: false);
    final rawCompleteness = _object(
      json['completeness'] ?? const {},
      'warm-up completeness',
    );
    final completeness = <String, bool>{};
    for (final entry in rawCompleteness.entries) {
      completeness[entry.key] = _requiredBool(
        entry.value,
        'warm-up completeness ${entry.key}',
      );
    }
    return B02WarmupRecommendation(
      availability: B02WarmupAvailability.parse(json['availability']),
      preference: json['preference'] == null
          ? null
          : B02WarmupPreference.parse(json['preference']),
      selectedSource: json['selectedSource'] == null
          ? null
          : B02WarmupTargetSource.parse(json['selectedSource']),
      loadBasis: json['loadBasis'] == null
          ? null
          : B02LoadBasis.parse(json['loadBasis']),
      workingLoadKg: _optionalDouble(
        json['workingLoadKg'],
        'warm-up working load',
      ),
      requestedCount: _requiredInt(
        json['requestedCount'],
        'warm-up request count',
      ),
      incrementKg: _optionalDouble(json['incrementKg'], 'warm-up increment'),
      incrementUnavailable: json['incrementUnavailable'] == null
          ? false
          : _requiredBool(
              json['incrementUnavailable'],
              'warm-up increment availability',
            ),
      reason: _requiredString(json['reason'], 'warm-up reason'),
      completeness: completeness,
      proposals: proposals,
    );
  }

  Map<String, dynamic> toJson() => {
    'ruleVersion': ruleVersion,
    'availability': availability.dbValue,
    if (preference != null) 'preference': preference!.dbValue,
    if (selectedSource != null) 'selectedSource': selectedSource!.dbValue,
    if (loadBasis != null) 'loadBasis': loadBasis!.dbValue,
    if (workingLoadKg != null) 'workingLoadKg': workingLoadKg,
    'requestedCount': requestedCount,
    if (incrementKg != null) 'incrementKg': incrementKg,
    'incrementUnavailable': incrementUnavailable,
    'reason': reason,
    'completeness': completeness,
    'proposals': proposals.map((proposal) => proposal.toJson()).toList(),
  };
}

class B02ExerciseExecutionPreference {
  final B02WarmupPreference? warmupPreference;
  final int? warmupSetCount;
  final int? customRestSeconds;

  B02ExerciseExecutionPreference({
    this.warmupPreference,
    this.warmupSetCount,
    this.customRestSeconds,
  }) {
    if (warmupSetCount != null &&
        (warmupSetCount! < 1 || warmupSetCount! > 4)) {
      throw B02ValidationException(
        'Warm-up set count must be between 1 and 4.',
      );
    }
    _nonNegative(customRestSeconds, 'custom rest');
  }
}

class B02ExecutionDraftState {
  static const int schemaVersion = 2;

  final String snapshotId;
  final int snapshotVersion;
  final B02ActivityType activityType;
  final String routineName;
  final int elapsedSeconds;
  final int? currentGroupOrdinal;
  final String? currentGroupId;
  final int? currentRoundOrdinal;
  final int? currentMemberOrdinal;
  final int currentExerciseOrdinal;
  final int currentSetOrdinal;
  final List<B02ExerciseGroup> groups;
  final List<B02PerformedExerciseDraft> performedExercises;
  final List<B02RestPeriod> restPeriods;
  final B02WarmupRecommendation? warmupRecommendation;
  final B02CardioSessionDetail? cardioDetail;
  final B02MobilitySessionDetail? mobilityDetail;

  B02ExecutionDraftState({
    required this.snapshotId,
    required this.snapshotVersion,
    required this.activityType,
    required this.routineName,
    required this.elapsedSeconds,
    this.currentGroupOrdinal,
    this.currentGroupId,
    this.currentRoundOrdinal,
    this.currentMemberOrdinal,
    required this.currentExerciseOrdinal,
    required this.currentSetOrdinal,
    this.groups = const [],
    this.performedExercises = const [],
    this.restPeriods = const [],
    this.warmupRecommendation,
    this.cardioDetail,
    this.mobilityDetail,
  }) {
    _requiredString(snapshotId, 'snapshot id');
    _atLeast(snapshotVersion, 1, 'snapshot version');
    _requiredString(routineName, 'routine name');
    _nonNegative(elapsedSeconds, 'elapsed seconds');
    if (currentGroupOrdinal != null && currentGroupOrdinal! < 0) {
      throw B02ValidationException('Current group ordinal is invalid.');
    }
    if (currentRoundOrdinal != null && currentRoundOrdinal! < 0) {
      throw B02ValidationException('Current round ordinal is invalid.');
    }
    if (currentMemberOrdinal != null && currentMemberOrdinal! < 0) {
      throw B02ValidationException('Current member ordinal is invalid.');
    }
    if (currentExerciseOrdinal < 0 || currentSetOrdinal < 0) {
      throw B02ValidationException('Current execution position is invalid.');
    }
    if ((currentGroupOrdinal == null) != (currentGroupId == null)) {
      throw B02ValidationException(
        'Current group position requires both ordinal and ID.',
      );
    }
    final isCardio = [
      B02ActivityType.running,
      B02ActivityType.cycling,
      B02ActivityType.walking,
    ].contains(activityType);
    final isMobility = [
      B02ActivityType.yoga,
      B02ActivityType.mobility,
    ].contains(activityType);
    if (isCardio &&
        (cardioDetail == null || cardioDetail!.activityType != activityType)) {
      throw B02ValidationException(
        'Cardio drafts require matching typed cardio details.',
      );
    }
    if (isMobility &&
        (mobilityDetail == null ||
            mobilityDetail!.practiceType != activityType)) {
      throw B02ValidationException(
        'Yoga or mobility drafts require matching typed practice details.',
      );
    }
    if (!isCardio && cardioDetail != null) {
      throw B02ValidationException(
        'Only cardio drafts may carry cardio details.',
      );
    }
    if (!isMobility && mobilityDetail != null) {
      throw B02ValidationException(
        'Only yoga or mobility drafts may carry mobility details.',
      );
    }
    _contiguousOrdinals(groups.map((group) => group.ordinal), 'Group');
    _contiguousOrdinals(
      performedExercises.map((exercise) => exercise.ordinal),
      'Performed exercise',
    );
  }

  factory B02ExecutionDraftState.fromJson(Map<String, dynamic> json) {
    final groups = _list(json['groups'] ?? const [], 'groups')
        .map((raw) => B02ExerciseGroup.fromJson(_object(raw, 'group')))
        .toList(growable: false);
    final performedExercises =
        _list(json['performedExercises'] ?? const [], 'performed exercises')
            .map(
              (raw) => B02PerformedExerciseDraft.fromJson(
                _object(raw, 'performed exercise'),
              ),
            )
            .toList(growable: false);
    final restPeriods = _list(json['restPeriods'] ?? const [], 'rest periods')
        .map((raw) => B02RestPeriod.fromJson(_object(raw, 'rest period')))
        .toList(growable: false);
    final warmupRecommendation = json['warmupRecommendation'] == null
        ? null
        : B02WarmupRecommendation.fromJson(
            _object(json['warmupRecommendation'], 'warm-up recommendation'),
          );
    final cardioDetail = json['cardioDetail'] == null
        ? null
        : B02CardioSessionDetail.fromJson(
            _object(json['cardioDetail'], 'cardio detail'),
          );
    final mobilityDetail = json['mobilityDetail'] == null
        ? null
        : B02MobilitySessionDetail.fromJson(
            _object(json['mobilityDetail'], 'mobility detail'),
          );
    return B02ExecutionDraftState(
      snapshotId: _requiredString(json['snapshotId'], 'snapshot id'),
      snapshotVersion: _requiredInt(
        json['snapshotVersion'],
        'snapshot version',
      ),
      activityType: B02ActivityType.parse(json['activityType']),
      routineName: _requiredString(json['routineName'], 'routine name'),
      elapsedSeconds: _requiredInt(json['elapsedSeconds'], 'elapsed seconds'),
      currentGroupOrdinal: _optionalInt(
        json['currentGroupOrdinal'],
        'current group ordinal',
      ),
      currentGroupId: _optionalString(
        json['currentGroupId'],
        'current group id',
      ),
      currentRoundOrdinal: _optionalInt(
        json['currentRoundOrdinal'],
        'current round ordinal',
      ),
      currentMemberOrdinal: _optionalInt(
        json['currentMemberOrdinal'],
        'current member ordinal',
      ),
      currentExerciseOrdinal: _requiredInt(
        json['currentExerciseOrdinal'],
        'current exercise ordinal',
      ),
      currentSetOrdinal: _requiredInt(
        json['currentSetOrdinal'],
        'current set ordinal',
      ),
      groups: groups,
      performedExercises: performedExercises,
      restPeriods: restPeriods,
      warmupRecommendation: warmupRecommendation,
      cardioDetail: cardioDetail,
      mobilityDetail: mobilityDetail,
    );
  }

  B02ExecutionDraftState copyWith({
    int? elapsedSeconds,
    List<B02PerformedExerciseDraft>? performedExercises,
    List<B02RestPeriod>? restPeriods,
    B02WarmupRecommendation? warmupRecommendation,
    B02CardioSessionDetail? cardioDetail,
    B02MobilitySessionDetail? mobilityDetail,
  }) {
    return B02ExecutionDraftState(
      snapshotId: snapshotId,
      snapshotVersion: snapshotVersion,
      activityType: activityType,
      routineName: routineName,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentGroupOrdinal: currentGroupOrdinal,
      currentGroupId: currentGroupId,
      currentRoundOrdinal: currentRoundOrdinal,
      currentMemberOrdinal: currentMemberOrdinal,
      currentExerciseOrdinal: currentExerciseOrdinal,
      currentSetOrdinal: currentSetOrdinal,
      groups: groups,
      performedExercises: performedExercises ?? this.performedExercises,
      restPeriods: restPeriods ?? this.restPeriods,
      warmupRecommendation: warmupRecommendation ?? this.warmupRecommendation,
      cardioDetail: cardioDetail ?? this.cardioDetail,
      mobilityDetail: mobilityDetail ?? this.mobilityDetail,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'snapshotId': snapshotId,
    'snapshotVersion': snapshotVersion,
    'activityType': activityType.dbValue,
    'routineName': routineName,
    'elapsedSeconds': elapsedSeconds,
    if (currentGroupOrdinal != null) 'currentGroupOrdinal': currentGroupOrdinal,
    if (currentGroupId != null) 'currentGroupId': currentGroupId,
    if (currentRoundOrdinal != null) 'currentRoundOrdinal': currentRoundOrdinal,
    if (currentMemberOrdinal != null)
      'currentMemberOrdinal': currentMemberOrdinal,
    'currentExerciseOrdinal': currentExerciseOrdinal,
    'currentSetOrdinal': currentSetOrdinal,
    'groups': groups.map((group) => group.toJson()).toList(),
    'performedExercises': performedExercises
        .map((exercise) => exercise.toJson())
        .toList(),
    'restPeriods': restPeriods.map((period) => period.toJson()).toList(),
    if (warmupRecommendation != null)
      'warmupRecommendation': warmupRecommendation!.toJson(),
    if (cardioDetail != null) 'cardioDetail': cardioDetail!.toJson(),
    if (mobilityDetail != null) 'mobilityDetail': mobilityDetail!.toJson(),
  };
}
