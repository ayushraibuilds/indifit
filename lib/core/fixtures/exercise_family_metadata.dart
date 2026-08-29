import 'package:flutter/foundation.dart';

import 'exercise_identity_fixtures.dart';

enum ExerciseFamilyMemberRole { base, variant }

@immutable
class ExerciseFamilyMemberMetadata {
  const ExerciseFamilyMemberMetadata({
    required this.exerciseId,
    required this.role,
    this.variantLabel,
  });

  final String exerciseId;
  final ExerciseFamilyMemberRole role;
  final String? variantLabel;
}

@immutable
class ExerciseFamilyMetadata {
  const ExerciseFamilyMetadata({
    required this.familyId,
    required this.baseExerciseId,
    required this.members,
    required this.approvalRecordId,
  });

  final String familyId;
  final String baseExerciseId;
  final List<ExerciseFamilyMemberMetadata> members;
  final String approvalRecordId;

  ExerciseFamilyMemberMetadata? memberFor(String exerciseId) {
    for (final member in members) {
      if (member.exerciseId == exerciseId) return member;
    }
    return null;
  }
}

final class ExerciseFamilyValidationException implements Exception {
  const ExerciseFamilyValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'Invalid exercise family metadata: ${errors.join('; ')}';
}

/// Exact-ID, presentation-only family lookup.
///
/// The reviewed production registry is sourced from the explicit family and
/// UUID bindings in R08_0_2_REPDB_MAPPING_REVIEW.csv. RepDB media approval is
/// deliberately independent: a rejected visual does not erase the reviewed
/// canonical family relationship. Names, muscles, equipment, aliases, and
/// replacement relationships never participate in runtime lookup.
@immutable
class ExerciseFamilyRegistry {
  const ExerciseFamilyRegistry._(
    this.families,
    this._familyById,
    this._familyByExerciseId,
  );

  factory ExerciseFamilyRegistry.validated({
    required List<ExerciseFamilyMetadata> families,
    required Set<String> knownExerciseIds,
  }) {
    final errors = validate(families, knownExerciseIds);
    if (errors.isNotEmpty) throw ExerciseFamilyValidationException(errors);
    return ExerciseFamilyRegistry._(
      List.unmodifiable(families),
      {for (final family in families) family.familyId: family},
      {
        for (final family in families)
          for (final member in family.members) member.exerciseId: family,
      },
    );
  }

  factory ExerciseFamilyRegistry.failOpen({
    required List<ExerciseFamilyMetadata> families,
    required Set<String> knownExerciseIds,
  }) {
    try {
      return ExerciseFamilyRegistry.validated(
        families: families,
        knownExerciseIds: knownExerciseIds,
      );
    } on ExerciseFamilyValidationException {
      return ExerciseFamilyRegistry.empty();
    }
  }

  const ExerciseFamilyRegistry.empty()
    : families = const [],
      _familyById = const {},
      _familyByExerciseId = const {};

  final List<ExerciseFamilyMetadata> families;
  final Map<String, ExerciseFamilyMetadata> _familyById;
  final Map<String, ExerciseFamilyMetadata> _familyByExerciseId;

  ExerciseFamilyMetadata? familyForExerciseId(String? exerciseId) {
    final id = exerciseId?.trim();
    if (id == null || id.isEmpty) return null;
    return _familyByExerciseId[id];
  }

  ExerciseFamilyMetadata? familyForId(String familyId) =>
      _familyById[familyId.trim()];

  static List<String> validate(
    List<ExerciseFamilyMetadata> families,
    Set<String> knownExerciseIds,
  ) {
    final errors = <String>[];
    final familyIds = <String>{};
    final claimedExerciseIds = <String, String>{};

    for (final family in families) {
      final familyId = family.familyId.trim();
      if (familyId.isEmpty) {
        errors.add('Family ID must not be empty');
      } else if (!familyIds.add(familyId)) {
        errors.add('Duplicate family ID $familyId');
      }
      if (family.approvalRecordId.trim().isEmpty) {
        errors.add('$familyId has no approval record');
      }
      if (family.members.length < 2) {
        errors.add('$familyId must contain a base and at least one variant');
      }

      final memberIds = <String>{};
      var baseCount = 0;
      for (final member in family.members) {
        final memberId = member.exerciseId.trim();
        if (memberId.isEmpty) {
          errors.add('$familyId has an empty member ID');
          continue;
        }
        if (!knownExerciseIds.contains(memberId)) {
          errors.add('$familyId references unknown exercise $memberId');
        }
        if (!memberIds.add(memberId)) {
          errors.add('$familyId repeats exercise $memberId');
        }
        final priorFamily = claimedExerciseIds[memberId];
        if (priorFamily != null && priorFamily != familyId) {
          errors.add('$memberId belongs to both $priorFamily and $familyId');
        } else {
          claimedExerciseIds[memberId] = familyId;
        }

        if (member.role == ExerciseFamilyMemberRole.base) {
          baseCount += 1;
          if (memberId != family.baseExerciseId) {
            errors.add('$familyId base member does not match baseExerciseId');
          }
          if (member.variantLabel != null) {
            errors.add('$familyId base member must not have a variant label');
          }
        } else if (member.variantLabel?.trim().isEmpty != false) {
          errors.add('$familyId variant $memberId needs a label');
        }
      }

      if (!memberIds.contains(family.baseExerciseId)) {
        errors.add('$familyId baseExerciseId is not a member');
      }
      if (!knownExerciseIds.contains(family.baseExerciseId)) {
        errors.add(
          '$familyId references unknown base ${family.baseExerciseId}',
        );
      }
      if (baseCount != 1) {
        errors.add('$familyId must have exactly one base member');
      }
    }
    return List.unmodifiable(errors);
  }
}

final ExerciseFamilyRegistry reviewedExerciseFamilyRegistry =
    ExerciseFamilyRegistry.failOpen(
      families: reviewedExerciseFamilies,
      knownExerciseIds: ExerciseCatalogManifest.goldenCatalogUuids.values
          .toSet(),
    );

final List<ExerciseFamilyMetadata> reviewedExerciseFamilies = List.unmodifiable(
  _reviewedFamilySeeds.map((seed) => seed.toMetadata()),
);

@immutable
class _ReviewedFamilySeed {
  const _ReviewedFamilySeed(
    this.familyId,
    this.baseExerciseId,
    this.standardExerciseId,
    this.pauseExerciseId,
    this.slowEccentricExerciseId,
  );

  final String familyId;
  final String baseExerciseId;
  final String standardExerciseId;
  final String pauseExerciseId;
  final String slowEccentricExerciseId;

  ExerciseFamilyMetadata toMetadata() => ExerciseFamilyMetadata(
    familyId: familyId,
    baseExerciseId: baseExerciseId,
    approvalRecordId: 'REC-R08-02-$familyId',
    members: [
      ExerciseFamilyMemberMetadata(
        exerciseId: baseExerciseId,
        role: ExerciseFamilyMemberRole.base,
      ),
      ExerciseFamilyMemberMetadata(
        exerciseId: standardExerciseId,
        role: ExerciseFamilyMemberRole.variant,
        variantLabel: 'Standard',
      ),
      ExerciseFamilyMemberMetadata(
        exerciseId: pauseExerciseId,
        role: ExerciseFamilyMemberRole.variant,
        variantLabel: 'Pause',
      ),
      ExerciseFamilyMemberMetadata(
        exerciseId: slowEccentricExerciseId,
        role: ExerciseFamilyMemberRole.variant,
        variantLabel: 'Slow eccentric',
      ),
    ],
  );
}

// Each positional field is role-specific. This is curated metadata, not a
// runtime technique/name parser.
const List<_ReviewedFamilySeed> _reviewedFamilySeeds = [
  _ReviewedFamilySeed(
    'FAM-01',
    '089ec703-a25e-5b12-a39a-78b17ee33742',
    'b70e7a1c-ec87-578f-bfeb-8fbdbceaf2ca',
    'f5d1ceeb-fe66-51f7-bd58-6c3e9874a969',
    'f9c0eb18-fc35-515c-bf18-f9bf6e1e1a5f',
  ),
  _ReviewedFamilySeed(
    'FAM-02',
    '256fb9bd-77a8-5ea5-ab07-cb10d65bce67',
    '2d6bbfa9-7c25-5463-b8c2-4a5eec542dd7',
    'c3c0efc1-7d1a-512c-afbf-aa58832a8435',
    '6dbfc969-9524-5d55-8dd2-8eb99a9b708d',
  ),
  _ReviewedFamilySeed(
    'FAM-03',
    '767caf63-b617-5a2f-9a01-a22b55918316',
    'f2103bf2-af7f-5133-87d8-b8786f3eaf7e',
    'a5854b31-1917-565c-8d1a-7e88e2a5772d',
    '5cdc2480-a820-57e5-87fd-73743346ad72',
  ),
  _ReviewedFamilySeed(
    'FAM-04',
    '74aa39bb-ff5a-5ff7-8cbe-e75878af3cf3',
    '8fe2c474-0f11-5d9c-be8a-c60318ce992e',
    '2fa5be19-f538-5182-82dc-df4c0840cb8f',
    '52495689-5ee4-59e5-b1a7-640a45fd8100',
  ),
  _ReviewedFamilySeed(
    'FAM-05',
    '91fe3e17-b76e-57b1-b4ef-bc615cb38c5d',
    'b20a3a7f-ae82-5555-89f5-19ae1fa3c749',
    'bfdfef59-a292-5ee3-a5aa-c3a5e845c43d',
    'c01c0c9e-561b-53c8-aa5e-26fbd0eb4e5e',
  ),
  _ReviewedFamilySeed(
    'FAM-06',
    'd1ea21fb-ca2a-5fe4-b529-1a48c66e2c3e',
    'dbafb9d3-d2eb-5460-a2ef-98cf1eb19bc5',
    '8470a7d9-c020-5fe8-ba68-d0bfebe706e2',
    '61bc7ff5-e8d9-5e92-ba7d-fe3910c22d4f',
  ),
  _ReviewedFamilySeed(
    'FAM-07',
    'b102bfa4-6cc5-5e60-accb-82a1ae39b8bc',
    '7fd950ce-79e5-5558-86d7-fc197b1026ea',
    '18b6bdf9-9941-5bb1-9369-1c8d73f41560',
    '3bc421ec-ab46-5c7c-a9fb-ce137b9bf737',
  ),
  _ReviewedFamilySeed(
    'FAM-08',
    '30dcad52-0a4d-55a4-a33b-e8923f85a51a',
    '924f6bfe-7c00-5dca-b6a0-9bbd38771b0f',
    'a9424a05-8453-52ea-aee4-b94ae2a2fbfe',
    'aa3707c7-fc1b-51cf-987c-7fd002d64e5e',
  ),
  _ReviewedFamilySeed(
    'FAM-09',
    '84011c13-4413-5779-8e7c-64f6a7860c68',
    '325be024-0a2a-5752-81c3-117d833ca80b',
    '82bc5ef4-2fcc-5752-8c52-3f407263cacd',
    '0f26c6a6-7e5f-5099-aa2e-b8ee59d2c99e',
  ),
  _ReviewedFamilySeed(
    'FAM-10',
    'b353d5f5-6116-5410-b6b3-50b2d78aea57',
    'c920003d-fd67-5632-af80-571261d344d6',
    'ecdbffb9-e1c9-516a-a217-cf42bad1a131',
    '11191d4f-9d7c-5501-9d1e-6dc1e172273c',
  ),
  _ReviewedFamilySeed(
    'FAM-11',
    '4e17e360-9f97-5cd4-a68c-c9dc1dcd7724',
    '15b91f5f-c007-5afa-98c0-8e2154eb84b6',
    '96fa8741-f9d7-51a8-b9a6-8276c0d48e9a',
    'f1fd96e9-e59c-54dd-ab83-9ee1ad3747be',
  ),
  _ReviewedFamilySeed(
    'FAM-12',
    '9fae7317-b8a5-5f5c-ba93-9d1611fb21dc',
    'a9996115-566e-5d9a-b7b4-2634ffe5e97c',
    'e78325b4-b36a-5bf3-a6a8-c7e5eecb1066',
    '916b7eb0-fa0c-5e4c-b7e9-57635901091f',
  ),
  _ReviewedFamilySeed(
    'FAM-13',
    'd3b5ab04-74f6-5155-9621-50238644eeda',
    '73d7db9e-67f2-5311-a106-31bca1914a95',
    '3bf3d06e-5e1d-5d47-b05f-0b954ec89de9',
    '1b4fa856-03b8-5c6b-81ca-8df9b13721d4',
  ),
  _ReviewedFamilySeed(
    'FAM-14',
    '081ed879-f46b-592a-8982-345f0f01dd3f',
    '1b692ec8-40d9-53e5-a7dd-47af7606d42b',
    'd167dea0-e52d-59dd-9ad9-1c597bbf65ab',
    '26ce5ae7-2f08-55a2-b015-c60ae6307d3b',
  ),
  _ReviewedFamilySeed(
    'FAM-15',
    '7887c839-1b15-5005-a0c9-b942842548e3',
    '8f4249e1-62c9-50be-a30c-e5f90b0b61ff',
    '5742f3b8-9595-591c-a042-bc11a162840c',
    'ccfda1c6-c811-538c-89cf-be67fa8fe932',
  ),
  _ReviewedFamilySeed(
    'FAM-16',
    '568fcfd9-bb09-5299-a898-801e93216770',
    '7c25a9f3-00af-5e09-b667-a6f9d9c024e2',
    '56feb751-efbb-5302-902d-940d45697261',
    'e87b0d6a-0a2c-595b-b241-89fc0d6f32fb',
  ),
  _ReviewedFamilySeed(
    'FAM-17',
    '59ff6c53-7932-57e3-a546-07ac2aa457ae',
    '84776ac4-f142-55cd-92f6-fa35a74956d3',
    '9fb9ee61-0792-5eef-a5f7-923914649294',
    '4f035379-6a9e-52a9-bb2b-b4c608808ba6',
  ),
  _ReviewedFamilySeed(
    'FAM-18',
    '426ff89a-6639-51d1-a6c1-33184586bbed',
    'b1e568c2-89f5-5689-b8d7-ee46d1205cf1',
    '419c463a-1d6a-5e6c-9000-54832b5116f5',
    '3c34c8f2-ce64-5f74-b002-e55775759e6d',
  ),
  _ReviewedFamilySeed(
    'FAM-19',
    'd8a67487-1f7a-5bed-b1aa-62537870b25b',
    '13e0d854-7591-586e-813f-4a462fbd1722',
    'f187e832-fdfa-5c75-a9bd-2cb19ff122f7',
    'a6b5fe22-9279-5ade-8f1e-f7d1cc323f80',
  ),
  _ReviewedFamilySeed(
    'FAM-20',
    'd2674149-5f1c-529b-9e3e-136fef2d8933',
    '93e0d927-843c-55e1-aa47-39071e715a63',
    '209a82cb-2a0f-5905-8d1a-a35cf35945fb',
    '1f05a67e-8cc2-5b02-a6b9-76bee46e3beb',
  ),
  _ReviewedFamilySeed(
    'FAM-21',
    '37088aa5-6989-5241-8ad9-23f1687a9435',
    '1976abfd-1c4a-5d9c-8788-2f86ee8f1b61',
    'e6d19944-fd95-5213-9bcb-89b1cc507ab4',
    'ea431a7f-19b8-5e5e-9e4c-da6298f4c50e',
  ),
  _ReviewedFamilySeed(
    'FAM-22',
    'c6422f26-c3ca-5a2b-9796-e4a3c17d1563',
    '5a039bbb-5edf-50a9-bbb5-3f349555689d',
    '0fa6d488-a6a9-56e0-ad16-401162373b19',
    'b095c880-f806-5b29-a2e0-300632a48796',
  ),
  _ReviewedFamilySeed(
    'FAM-23',
    '7acd7ccb-01ec-5c3a-80c8-7797efcd3302',
    '7834b7ff-ccfb-5d3b-b06a-0d36f1621841',
    'e3003cca-416b-599f-a691-c2d976688108',
    'd095fe23-fbe7-5944-a9e9-b244cc6c52ce',
  ),
  _ReviewedFamilySeed(
    'FAM-24',
    '5e5620d2-4170-5f2a-bd3d-a1c0070480c9',
    'b8dbb448-b55b-524a-94e8-b485abc563db',
    'f76c4d8d-6b3f-5ac7-8589-1dedba951634',
    '84e64439-e26f-5ad4-80ab-587f29ff1a74',
  ),
  _ReviewedFamilySeed(
    'FAM-25',
    '6c8e559c-a8f8-59f0-a761-81d9c4cf4aa7',
    '5a555f32-2b94-58b7-a627-708df73096f9',
    'c1b4df37-8a58-5053-8f41-f6aeb8990f8f',
    '37582935-75f9-5fe3-aa4e-8891f6fdc35a',
  ),
  _ReviewedFamilySeed(
    'FAM-26',
    '93760f3b-6f76-5856-9e79-0022911863cc',
    'b9ba7916-de0c-5068-a4e1-39fa395b0a31',
    '4cab0e37-bdbe-53e9-bf46-50309381ea17',
    '64074bfd-2840-5974-ba9e-2e3e46748509',
  ),
  _ReviewedFamilySeed(
    'FAM-27',
    'a5650e7a-0cb9-5acb-8d66-889d2289e647',
    '9b638815-f580-511c-9f06-3d3fa0e12d0a',
    'aecb66d9-5817-5093-83c6-1e56a236854e',
    '58200cd2-1ea4-509a-8ef9-77467602f9af',
  ),
  _ReviewedFamilySeed(
    'FAM-28',
    'cb6bc77b-5a4b-5b00-9e8a-4d0c790f37a7',
    'b6e6e3a7-6896-5362-ba5c-68b66c70263b',
    '5433b78a-3583-56f4-a264-cb1c6495af7b',
    '4e154d93-302a-5ccb-97a9-fa684cbffbf2',
  ),
  _ReviewedFamilySeed(
    'FAM-29',
    '9cb62691-e65f-56f4-9a93-c82a4834a448',
    '680d6269-6d0f-5d37-bc56-c851de59ef76',
    '8c01c75a-b425-53ac-9892-7b5d3f2d664c',
    '4119c3bb-cd5a-5027-91e4-5d3edd747a30',
  ),
  _ReviewedFamilySeed(
    'FAM-30',
    'b8f0b194-2d41-5514-bc2c-a2bdabbe056e',
    'a570013f-3743-5c80-8f40-5fed726b4925',
    '1230840b-9006-525b-a392-bfe9faf7cfe5',
    '1fc82856-abad-5a9f-ae6c-73069ff0c36b',
  ),
  _ReviewedFamilySeed(
    'FAM-31',
    '4f71798e-7893-51a2-b542-090c03df5cb6',
    '81d3dde6-4f93-586f-8f76-c96256e82135',
    '386ded7b-1307-5ebb-b76d-f5dde4cb1ec3',
    '8dd8f09b-5e0c-56b7-bb45-55d58947db72',
  ),
  _ReviewedFamilySeed(
    'FAM-32',
    'bdd4c5a6-ea2b-55e0-a6e0-206ea683b886',
    '3163de96-3fc3-533d-ab06-70ac27ae214c',
    '73601fc7-0d6a-5b78-84d4-499399470903',
    '695681c5-e86f-5bcc-930a-85d2ef73f583',
  ),
  _ReviewedFamilySeed(
    'FAM-33',
    '0bce1172-7f1c-5d38-9581-0bc2fc6807bb',
    '8ea9c7c8-75d9-53d1-a1d6-fefe851f1688',
    '29c7bd7d-342a-54ba-ad69-ebef5f15a7e2',
    '85c25be6-ccbd-5b87-9e4a-1edac4359256',
  ),
  _ReviewedFamilySeed(
    'FAM-34',
    '3525a526-c7a6-5d33-9758-4428da2760b6',
    '6edde0de-7492-5b33-ab28-5f27747c0bbc',
    'c166fed2-3d32-5641-94e5-8ea16ec447eb',
    'ab2ee7bc-cc73-55a9-b542-31821cac14ca',
  ),
  _ReviewedFamilySeed(
    'FAM-35',
    '803fcabc-ad1c-52ac-b956-9e85a593c6f3',
    '4d83d57c-2da7-50e0-a69f-f8dabc69135d',
    '704c2f48-894c-5197-9232-236d83fd8118',
    'da4d6b6f-ec07-5d98-b994-cb0bea76a66f',
  ),
];
