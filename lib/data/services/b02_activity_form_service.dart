import '../models/b02_execution_models.dart';

class B02ActivityFormDetails {
  final B02CardioSessionDetail? cardioDetail;
  final B02MobilitySessionDetail? mobilityDetail;

  const B02ActivityFormDetails({this.cardioDetail, this.mobilityDetail});
}

/// Builds typed activity details from primitive form values. Keeping interval
/// ordering and modality validation here prevents widgets from becoming a
/// second domain boundary.
class B02ActivityFormService {
  const B02ActivityFormService();

  B02ActivityFormDetails build({
    required B02ActivityType activityType,
    required int durationSeconds,
    int? distanceMetres,
    String? style,
    String? intensity,
    String? focusNote,
    bool isIntervalWorkout = false,
    int? workSeconds,
    int? recoverySeconds,
  }) {
    if (durationSeconds < 1) {
      throw const B02ValidationException('Duration must be positive.');
    }
    if (_cardioTypes.contains(activityType)) {
      final intervals = <B02CardioInterval>[];
      if (isIntervalWorkout) {
        if (workSeconds == null || workSeconds < 1) {
          throw const B02ValidationException(
            'Work interval seconds must be positive.',
          );
        }
        intervals.add(
          B02CardioInterval(
            id: 'manual-work-0',
            ordinal: 0,
            segmentType: B02CardioSegmentType.work,
            durationSeconds: workSeconds,
          ),
        );
        if (recoverySeconds != null && recoverySeconds > 0) {
          intervals.add(
            B02CardioInterval(
              id: 'manual-recovery-1',
              ordinal: 1,
              segmentType: B02CardioSegmentType.recovery,
              durationSeconds: recoverySeconds,
            ),
          );
        }
      }
      return B02ActivityFormDetails(
        cardioDetail: B02CardioSessionDetail(
          activityType: activityType,
          durationSeconds: durationSeconds,
          distanceMetres: distanceMetres,
          isIntervalWorkout: isIntervalWorkout,
          inputMode: B02InputMode.manual,
          intervals: intervals,
        ),
      );
    }
    if (_mobilityTypes.contains(activityType)) {
      return B02ActivityFormDetails(
        mobilityDetail: B02MobilitySessionDetail(
          practiceType: activityType,
          durationSeconds: durationSeconds,
          style: _clean(style),
          intensity: _clean(intensity),
          focusNote: _clean(focusNote),
        ),
      );
    }
    throw B02ValidationException(
      'Activity type ${activityType.dbValue} is not supported by manual typed activity entry.',
    );
  }

  static const _cardioTypes = {
    B02ActivityType.running,
    B02ActivityType.cycling,
    B02ActivityType.walking,
  };
  static const _mobilityTypes = {
    B02ActivityType.yoga,
    B02ActivityType.mobility,
  };

  String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
