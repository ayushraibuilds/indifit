import 'dart:convert';

import '../../database/app_database.dart';
import '../calendar_repository.dart';

/// Centralized validator for calendar occurrence lifecycle and state transitions.
class OccurrenceTransitionValidator {
  const OccurrenceTransitionValidator();

  void validateCommand(OccurrenceCommand command) {
    if (command.occurrenceId.trim().isEmpty ||
        command.commandId.trim().isEmpty) {
      throw ArgumentError('Occurrence and command IDs must not be blank.');
    }
  }

  void requireUnstarted(
    ScheduledSessionOccurrence occurrence,
    String action,
  ) {
    if (occurrence.status != OccurrenceStatus.planned.dbValue &&
        occurrence.status != OccurrenceStatus.rescheduled.dbValue) {
      throw InvalidOccurrenceTransitionException(
        'Cannot $action an occurrence in status ${occurrence.status}.',
      );
    }
  }

  void validateRepeatPurpose(
    ScheduledSessionOccurrence source,
    RepeatPurpose purpose,
  ) {
    if (source.status == OccurrenceStatus.completed.dbValue &&
        purpose != RepeatPurpose.extra) {
      throw const InvalidOccurrenceTransitionException(
        'Repeating completed work is always extra.',
      );
    }
    if (source.status == OccurrenceStatus.skipped.dbValue &&
        source.skipMode == 'advance' &&
        purpose != RepeatPurpose.extra) {
      throw const InvalidOccurrenceTransitionException(
        'A skip-and-advance occurrence can repeat only as extra work.',
      );
    }
  }

  void validateStartConfirmation({
    required String todayLocalDate,
    required String effectiveLocalDate,
    required bool confirmedOutsideEffectiveDate,
  }) {
    if (todayLocalDate != effectiveLocalDate &&
        !confirmedOutsideEffectiveDate) {
      throw const InvalidOccurrenceTransitionException(
        'Starting a past or future occurrence requires explicit confirmation.',
      );
    }
  }

  void validateRescheduleConfirmation(bool confirmed) {
    if (!confirmed) {
      throw const InvalidOccurrenceTransitionException(
        'Rescheduling requires an explicit confirmation.',
      );
    }
  }

  bool isTerminalStatus(String status) {
    return status == OccurrenceStatus.completed.dbValue ||
        status == OccurrenceStatus.partiallyCompleted.dbValue ||
        status == OccurrenceStatus.skipped.dbValue ||
        status == OccurrenceStatus.cancelled.dbValue;
  }

  Never throwStale() {
    throw const InvalidOccurrenceTransitionException(
      'The occurrence changed before this command could be applied.',
    );
  }

  Map<String, dynamic> decodeAndValidateOccurrenceSnapshot(
    String snapshotJson,
    ScheduledSessionOccurrence occurrence,
  ) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(snapshotJson);
    } on Object {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    if (decoded is! Map) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    if (snapshot['occurrenceId'] != occurrence.id) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot belongs to another scheduled workout.',
      );
    }
    final template = snapshot['template'];
    if (template is! Map || template['id'] != occurrence.sessionTemplateId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot no longer matches its scheduled workout.',
      );
    }
    final version = snapshot['programVersion'];
    if (version is! Map || version['id'] != occurrence.programVersionId) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot no longer matches its training plan.',
      );
    }
    if (snapshot['routineName'] is! String ||
        (snapshot['routineName'] as String).trim().isEmpty ||
        snapshot['prescriptions'] is! List) {
      throw const InvalidOccurrenceTransitionException(
        'This workout snapshot is unavailable right now.',
      );
    }
    return snapshot;
  }
}
