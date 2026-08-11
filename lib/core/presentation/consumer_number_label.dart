import 'package:intl/intl.dart';

/// Presentation-only number formatting for compact consumer summaries.
/// Stored nutrition values remain unchanged.
abstract final class ConsumerNumberLabel {
  static String rounded(double value) {
    if (!value.isFinite) return '—';
    return NumberFormat.decimalPattern().format(value.round());
  }
}
