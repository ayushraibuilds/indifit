/// Small consumer-facing count formatter for nouns that need singular and
/// plural copy without changing any domain values.
class ConsumerCountLabel {
  const ConsumerCountLabel._();

  static String format(int count, String singular, {String? plural}) {
    final noun = count == 1 ? singular : (plural ?? '${singular}s');
    return '$count $noun';
  }
}
