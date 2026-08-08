import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_progress_read_models.dart';

/// Consumer copy for the B02 progress surface. The read model remains the
/// source of truth; this adapter only chooses wording and labels.
abstract final class B02ProgressPresentation {
  static String range(B02ProgressQuery query) =>
      ConsumerDateLabel.range(query.startLocalDate, query.endLocalDate);

  static String activityEmpty() =>
      'Complete a workout to start building your activity history.';

  static String groupEmpty() =>
      'Complete a strength workout with a group to see it here.';

  static String targetEmpty() =>
      'Complete a strength workout to start seeing progress.';

  static String muscleEmpty() =>
      'Complete a workout to see which muscle groups you’re training.';

  static String incompleteMetric() =>
      'Some progress details are still being prepared.';

  static String date(DateTime value) => ConsumerDateLabel.dateTime(value);

  static String sourceLabel(B02ActivitySource? source, {bool legacy = false}) {
    if (legacy) return 'Earlier workout';
    return switch (source) {
      B02ActivitySource.manual => 'Logged by you',
      B02ActivitySource.healthImport => 'Health data',
      null => 'Workout',
    };
  }

  static String status(String value) {
    final key = value.trim().toLowerCase().replaceAll('-', '_');
    return switch (key) {
      'partial' => 'Partly complete',
      'complete' || 'completed' => 'Complete',
      'unknown' || 'missing' || 'invalid' => 'Not available yet',
      _ => ConsumerCopy.state(key),
    };
  }

  static String confidence(String? value) => switch (value) {
    'high' => 'High confidence',
    'medium' => 'Medium confidence',
    'low' => 'Low confidence',
    _ => 'Confidence not available',
  };
}
