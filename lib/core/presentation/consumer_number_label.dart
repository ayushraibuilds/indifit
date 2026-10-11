import 'package:intl/intl.dart';

/// Presentation-only number formatting for compact consumer summaries.
/// Stored nutrition values remain unchanged.
abstract final class ConsumerNumberLabel {
  static String rounded(double value) {
    if (!value.isFinite) return '—';
    return NumberFormat.decimalPattern().format(value.round());
  }

  /// "22 g", or "3.8 g" under 10 g where the decimal still matters.
  static String grams(double value) {
    if (!value.isFinite) return '—';
    if (value.abs() >= 10) return '${rounded(value)} g';
    final tenths = (value * 10).round() / 10;
    final text = tenths == tenths.roundToDouble()
        ? tenths.toStringAsFixed(0)
        : tenths.toStringAsFixed(1);
    return '$text g';
  }
}
