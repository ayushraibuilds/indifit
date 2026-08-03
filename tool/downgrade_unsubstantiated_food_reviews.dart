import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const manifestPath = 'assets/data/nutrition_food_identity_manifest.json';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final file = File(manifestPath);
  final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final entries = (payload['entries'] as List).cast<Map<String, dynamic>>();
  final reviews = (payload['source_reviews'] as Map)
      .map<String, Map<String, dynamic>>(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      );

  const explicitlyReviewedByAlias = <String, Map<String, String>>{
    'asset:base:masala dosa': {
      'evidence_ref': 'manifest:approved-alias:alias-masala-dosai',
      'reason':
          'Explicit approved Masala Dosai alias targets this exact bundled source key; no fuzzy or generic match is used.',
    },
    'asset:base:whole wheat roti / chapati': {
      'evidence_ref': 'manifest:approved-alias:alias-whole-wheat-chapati',
      'reason':
          'Explicit approved Whole Wheat Chapati alias targets this exact bundled source key.',
    },
    'asset:regional/bengali:chholar dal': {
      'evidence_ref': 'manifest:approved-alias:alias-cholar-dal',
      'reason':
          'Explicit approved Cholar Dal alias targets this exact Bengali source key; generic Dal remains ambiguous.',
    },
    'asset:regional/gujarati:thepla (methi)': {
      'evidence_ref': 'manifest:approved-alias:alias-methi-thepla',
      'reason':
          'Explicit approved Methi Thepla alias targets this exact Gujarati source key.',
    },
    'asset:regional/maharashtrian:poha (kanda poha)': {
      'evidence_ref': 'manifest:approved-alias:alias-kanda-poha',
      'reason':
          'Explicit approved Kanda Poha alias targets this exact Maharashtra source key.',
    },
    'asset:regional/punjabi:sarson ka saag': {
      'evidence_ref': 'manifest:approved-alias:alias-sarson-saag',
      'reason':
          'Explicit approved Sarson Saag alias targets this exact Punjabi source key; generic names remain unresolved or ambiguous.',
    },
  };

  for (final entry in entries) {
    final sourceKey =
        (entry['provenance'] as Map<String, dynamic>)['key'] as String;
    final review = reviews[sourceKey];
    if (review == null) {
      if (entry['is_catalogue'] == true) {
        throw StateError('Catalogue entry has no source review: $sourceKey');
      }
      continue;
    }
    final explicitEvidence = explicitlyReviewedByAlias[sourceKey];
    if (explicitEvidence == null) {
      entry['review_state'] = 'manualReview';
      review['review_state'] = 'manualReview';
      review['reason'] =
          'No per-record review evidence is checked in; preserved kind and variant metadata are a maintenance suggestion only.';
      review['evidence_ref'] = null;
    } else {
      entry['review_state'] = 'reviewed';
      review['review_state'] = 'reviewed';
      review.addAll(explicitEvidence);
    }
    review.remove('reviewer');
  }

  payload['source_reviews'] = reviews;

  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
}
