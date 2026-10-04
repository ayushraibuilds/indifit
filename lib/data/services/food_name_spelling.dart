/// Everyday spellings of words the catalogue spells one way: the catalogue
/// says "Sabji", people also type "sabzi" or "subzi".
const Map<String, String> _spellingFolds = {
  'sabzi': 'sabji',
  'sabzee': 'sabji',
  'sabjee': 'sabji',
  'subzi': 'sabji',
  'subji': 'sabji',
};

final RegExp _spellingFoldPattern = RegExp(
  '\\b(${_spellingFolds.keys.join('|')})(s?)\\b',
  caseSensitive: false,
);

/// Rewrites [value]'s variant spellings to the catalogue's ("aloo gobi
/// sabzi" -> "aloo gobi sabji"), keeping everything else as it is.
String foldFoodSpellings(String value) => value.replaceAllMapped(
  _spellingFoldPattern,
  (match) =>
      '${_spellingFolds[match.group(1)!.toLowerCase()]!}${match.group(2)}',
);
