# R09-D minimum credible verification

Status: automated gate implemented. Public launch remains blocked until the
production-signed artifacts and required physical-device rows below are
recorded as passing.

## Release rule

IndiFit can enter closed beta only when all of the following are true:

- P0 blockers: **0**.
- Release-critical P1 defects: **0**.
- Static analysis and the complete automated suite pass on the release commit.
- The critical-journey lane below passes independently.
- A production-signed Android App Bundle and an App Store/TestFlight iOS
  archive pass identity, version, signing and install checks.
- Every required physical-device row has a named target, build identifier,
  result and evidence reference.

A green unsigned build or CI artifact is compiler evidence, not store-signing
or physical-device evidence.

## Seven critical automated journeys

The gate deliberately curates existing high-value tests instead of creating a
second exhaustive suite. Run it with:

```bash
bash tool/verify_r09_release.sh --tests-only
```

| Journey | Evidence selected by the runner |
| --- | --- |
| Fresh install → onboarding → Today | Router/startup and personalized-onboarding persistence/failure coverage |
| Food search → log → edit → diary/Progress | Fast logging, direct correction, atomic diary and factual Progress coverage |
| Choose workout → execute → rest → complete → Progress | Preparation, durable rest, exact completion and Progress coverage |
| Backup → mutate → restore | Backup-v10 round-trip/rollback and transactional restore coverage |
| Reminder setup → schedule → tap route | Editable/quiet-hours scheduling, stale suppression and every supported payload destination |
| Health/camera permission unavailable, denied or partial | Honest platform/permission state and usable partial-access coverage |
| Frozen V1 contract → platform safety → release identity | R09-A, R09-B and R09-C source/asset/signing invariants |

The normal CI job still runs the complete suite after this lane.

## Artifact evidence

`tool/verify_r09_artifacts.sh` fails closed on identity/version mismatches,
invalid APK/AAB signatures, SDK debug certificates, IndiFit's throwaway CI
certificate outside CI mode, missing Android bundle structure, missing iOS
assets/launch screen, unsigned iOS apps outside explicit compiler-proof mode,
or signed iOS identifiers that do not match `com.indifit.indifit`.

Local production build command:

```bash
bash tool/verify_r09_release.sh --artifacts --signed-ios
```

CI retains these non-distributable proofs for review:

- release APK and AAB signed with a throwaway CI-only certificate;
- unsigned iOS Release app bundle;
- SHA-256, size, identity, version and certificate/signing evidence records.

Only owner-controlled signing may produce store candidates. Never submit the
CI Android artifacts or the unsigned CI iOS bundle.

Store-signing prerequisites:

- replace `android/key.properties` with the owner-controlled upload keystore;
  the inspector intentionally rejects the repository-local throwaway
  `dummy.keystore` certificate;
- enable HealthKit and Data Protection for the final Apple App ID, then create
  or refresh a provisioning profile for `com.indifit.indifit` that contains
  both entitlements;
- verify that the signed iOS app retains
  `NSFileProtectionCompleteUntilFirstUserAuthentication`; do not remove this
  safety entitlement merely to make an incompatible provisioning profile pass.

## Required physical-device acceptance

Use exact device/OS and build identifiers. `Pending` means no claim has been
made; automated tests do not change it.

| ID | Scenario | Android result | iOS result | Evidence |
| --- | --- | --- | --- | --- |
| D01 | Fresh install, complete/skip onboarding, relaunch into Today | Pending | Pending | — |
| D02 | Offline local food search, log, edit, delete and confirm Progress | Pending | Pending | — |
| D03 | Start planned/quick workout, background during rest, resume, complete and confirm Progress | Pending | Pending | — |
| D04 | Force-stop/process death during active workout and recover exact draft | Pending | Pending | — |
| D05 | Create protected backup, mutate data, restore, and verify semantic equality | Pending | Pending | — |
| D06 | Deny/revoke camera, notification and Health access; confirm core app remains usable | Pending | Pending | — |
| D07 | Configure reminders, cross timezone/clock boundary, receive and tap each supported payload, suppress obsolete prompts | Pending | Pending | — |
| D08 | Light/dark, 320–430 pt class screen, 2× text and TalkBack/VoiceOver traversal | Pending | Pending | — |
| D09 | Upgrade from the last accepted beta without losing canonical data or preferences | Pending | Pending | — |

Minimum target matrix:

- one supported Android device near minimum API and one current Android device;
- one supported smaller iPhone and one current iPhone;
- at least one physical Health Connect target and one physical HealthKit target
  when Health functionality is part of the submitted binary.

## Known R09-D environment limitation

The current `mobile_scanner` Google ML Kit transitive stack warns that it lacks
arm64 support required by Apple Silicon iOS 26+ simulators. The physical-device
iOS Release build compiles. Simulator coverage must remain unclaimed until the
dependency is made compatible or the selected supported matrix proves a valid
alternative.

## Evidence record template

For each candidate, record:

```text
commit:
version/build:
artifact SHA-256:
signing certificate/team:
device and OS:
scenario ID:
result:
evidence link/path:
defect ID (if failed):
reviewer and date:
```
