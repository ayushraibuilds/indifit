# R08-0.2 Terra Independent RepDB Visual Review

## Executive summary

I independently reviewed all 35 IndiFit movement families against the actual review-only RepDB START/PEAK or MAIN images in `docs/implementation/r08/review_artifacts/repdb_mapping_review/`. The review used the pinned RepDB snapshot `045845b61e4aefd9e684fa84518b84c665ea3cd3`, the canonical 140-entry IndiFit catalog, and the canonical display-movement facts. Flash confidence, metadata similarity, and the contact-sheet candidate labels were treated as evidence only, not as an answer key.

Recommendation totals:

- `APPROVE_RECOMMENDED`: 30
- `REJECT_RECOMMENDED`: 4
- `NEEDS_HUMAN_REVIEW`: 1

The four clear fail-closed rejects are FAM-03 (no truthful decline Hammer Strength candidate), FAM-17 (prone/lying leg curl mapped to canonical seated leg curl), FAM-18 (loaded calf-raise machine mapped to canonical bodyweight standing calf raise), and FAM-35 (bent-knee hanging knee raise mapped to canonical straight-leg hanging leg raise). FAM-19 is defensible as one forward lunge step but does not visibly establish continuous walking or alternating locomotion, so it requires a human product decision.

These are recommendations only. No official mapping was changed to `APPROVED`, no canonical UUID was merged, and no production RepDB media was added.

## Review basis and rule application

- Reviewed 67 actual pinned review images: 33 START/PEAK pairs and the MAIN-only plank image. FAM-03 correctly has no candidate image.
- IndiFit canonical identity, equipment, cues, and taxonomy remain authoritative. RepDB muscle labels were not used to decide exercise identity.
- Pause, Standard, and Slow Eccentric UUIDs were evaluated for reuse of the underlying movement illustration only. The artwork is not expected to show tempo or pause duration.
- Grip and attachment specificity was accepted where it does not materially change the generic canonical movement. Wide-bar seated rows and EZ-bar preacher curls are recorded as specificity notes rather than rejected.
- Static MAIN-only plank artwork was accepted because the canonical movement is isometric and the pictured forearm plank matches the canonical body position.

## Family-by-family recommendations

| Family | IndiFit movement | RepDB movement | Recommendation | Visual correctness | Equipment | Position/orientation | Grip/stance | Range/direction | Variant reuse | Main concern | Reason |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FAM-01 | Flat Barbell Bench Press | Barbell Bench Press | APPROVE_RECOMMENDED | Match: flat barbell press | Match: barbell and flat bench | Supine on flat bench | Bilateral overhand bar grip; generic bench stance | Bar travels overhead to chest and returns; same press direction | YES | None material | START/PEAK clearly communicate a conventional flat barbell bench press. |
| FAM-02 | Incline Dumbbell Bench Press | Incline Dumbbell Press | APPROVE_RECOMMENDED | Match: incline dumbbell press | Match: dumbbells | Supine on a roughly 30–45 degree incline bench | Bilateral dumbbells; neutral-to-semi-pronated presentation is harmless | Dumbbells move from chest level to overhead and back | YES | None material | Incline, bilateral loading, and pressing direction are visually truthful. |
| FAM-03 | Decline Hammer Strength Press | NO_MATCH | REJECT_RECOMMENDED | No truthful candidate artwork supplied | No match: generic decline/barbell or other machine would not establish the plate-loaded convergent apparatus | Canonical decline machine setup is not represented | Not assessable because no candidate exists | Not assessable; do not infer from a related decline press | NO | Hammer Strength-style plate-loaded machine identity | The normal fallback chain should be used. Generic decline barbell or machine art would materially mislead the user. |
| FAM-04 | Chest Dips | Chest Dips | APPROVE_RECOMMENDED | Match: chest-biased dip pose | Match: bodyweight dip station | Supported hanging between parallel bars | Bilateral support; crossed ankles are harmless; torso leans forward at the bottom | Shoulder descends below elbow with elbows flexing, then presses back up | YES | RepDB primary-muscle label differs | The forward torso lean, shoulder position, and elbow path are sufficient for a chest-biased dip; taxonomy does not invalidate the artwork. |
| FAM-05 | Push-Ups | Push-Up | APPROVE_RECOMMENDED | Match: standard push-up | Match: bodyweight | Prone, unsupported plank line | Bilateral hands on floor, roughly shoulder-width | Chest lowers toward floor and presses to straight-arm support | YES | None material | The pair shows the canonical prone bodyweight press without a material variant. |
| FAM-06 | Cable Chest Fly | Cable Fly | APPROVE_RECOMMENDED | Match: standing bilateral cable fly | Match: cable towers and handles | Standing and unsupported | Bilateral handles; arms open in a broad arc | Arms move from wide/open to hands together at chest height | YES | None material | The cable path and fly arc are clear and not a cable press. |
| FAM-07 | Barbell Deadlift | Barbell Deadlift | APPROVE_RECOMMENDED | Match: conventional deadlift | Match: barbell | Standing bilateral floor pull with hip hinge | Bilateral overhand-looking bar grip; conventional stance | Bar rises from floor to standing lockout with the same vertical direction | YES | External RepDB taxonomy differs | The actual poses depict a conventional barbell deadlift; RepDB glute/hamstring labels do not change the visual judgment. |
| FAM-08 | Lat Pulldown | Lat Pulldown | APPROVE_RECOMMENDED | Match: seated pulldown | Match: cable machine and bar | Seated, facing the machine | Wide straight-bar grip is consistent with a generic pulldown | Bar travels from overhead to upper chest and returns | YES | Wide grip is specific but not misleading | Seated orientation, cable apparatus, and vertical pull direction are correct. |
| FAM-09 | Bent Over Barbell Row | Bent-Over Barbell Row | APPROVE_RECOMMENDED | Match: bent-over barbell row | Match: barbell | Standing hip-hinged, unsupported | Bilateral bar grip; stance is conventional | Bar moves from hanging below shoulders toward the torso | YES | None material | The bent-over posture and horizontal pull are unambiguous. |
| FAM-10 | One-Arm Dumbbell Row | Single-Arm Dumbbell Row | APPROVE_RECOMMENDED | Match: unilateral bench-supported row | Match: dumbbell and bench support | One knee/hand supported on bench; unilateral | One-arm dumbbell, with the opposite side supported | Dumbbell travels from hanging to the side of the torso | YES | Depicted side is fixed but canonical laterality is generic | The image is a truthful unilateral row; one shown side does not change the canonical family. |
| FAM-11 | Pull-Ups | Pull-Up | APPROVE_RECOMMENDED | Match: standard pull-up | Match: pull-up bar and bodyweight | Hanging unsupported from bar | Bilateral overhand/wide grip; no kipping or assistance shown | Body rises from dead hang toward bar and lowers back | YES | None material | The hanging setup and vertical pulling range match the canonical pull-up. |
| FAM-12 | Seated Cable Row | Wide Grip Seated Cable Row | APPROVE_RECOMMENDED | Match: seated cable row with wide-bar specificity | Match: cable machine | Seated with feet braced and torso upright | Wide straight-bar grip rather than a V-handle; canonical does not prescribe a specific attachment | Arms extend forward and pull the bar to the abdomen | YES | Attachment is visibly specific | This remains a generic seated cable row and does not materially misrepresent IndiFit's unspecialized canonical movement. |
| FAM-13 | Barbell Squat | Barbell Back Squat | APPROVE_RECOMMENDED | Match: bilateral barbell back squat | Match: barbell | Standing with bar supported across upper back | Bilateral back-squat stance and bar placement | Upright standing position descends to squat depth and returns | YES | None material | The bar position, stance, and squat direction are visually correct. |
| FAM-14 | Leg Press | Leg Press | APPROVE_RECOMMENDED | Match: 45-degree sled leg press | Match: leg-press machine | Seated/reclined against sled back pad | Bilateral feet on platform, conventional stance | Sled travels through knee/hip flexion to extension | YES | 45-degree sled is a machine-specific depiction | This is the ordinary generic leg-press apparatus and remains truthful for the canonical machine exercise. |
| FAM-15 | Romanian Deadlift (RDL) | Romanian Deadlift | APPROVE_RECOMMENDED | Match: barbell RDL hinge | Match: barbell | Standing, unsupported hip hinge | Bilateral barbell stance and grip | Bar lowers along the legs during hip hinge and returns to standing | YES | None material | The straight-leg-dominant hinge and bar path distinguish it from a conventional floor deadlift. |
| FAM-16 | Leg Extensions | Leg Extension | APPROVE_RECOMMENDED | Match: seated knee extension | Match: leg-extension machine | Seated with back supported | Bilateral lower-leg pad engagement | Knees move from flexion to extension and back | YES | None material | The machine, seated setup, and isolated knee-extension range match. |
| FAM-17 | Seated Leg Curl | Lying Leg Curl | REJECT_RECOMMENDED | No match: candidate is prone/lying | No match at the specific apparatus/setup level | Prone lying on the pad, not seated | Bilateral lower-leg pad; stance is not the issue | Knees flex from extended legs while prone | NO | Canonical seated versus candidate prone orientation | Seated and lying leg curls use materially different body orientation and apparatus geometry; fail closed. |
| FAM-18 | Standing Calf Raise | Standing Calf Raise | REJECT_RECOMMENDED | Movement direction matches, setup does not | No match: canonical is Bodyweight; image is a loaded shoulder-pad machine | Standing on a machine platform with shoulder pads and handles | Bilateral stance is fine, but machine support is prominent | Heels rise and lower through plantarflexion | NO | Bodyweight versus machine-specific apparatus | The canonical catalog explicitly uses bodyweight standing calf raises on a step edge; this machine image would mislead the user about the exercise setup. |
| FAM-19 | Walking Lunges | Dumbbell Lunge | NEEDS_HUMAN_REVIEW | Defensible for one forward lunge step, but locomotion is not shown | Match: dumbbells | Standing start to unilateral forward split-lunge position | Bilateral dumbbells; one forward leg is shown | Pair shows a forward lunge descent but not return, alternation, or continuous travel | NEEDS_HUMAN_REVIEW | Walking versus stationary/one-step representation | Product owner must decide whether this static start/peak pair is sufficient as underlying Walking Lunges art or whether visible locomotion/alternation is required. |
| FAM-20 | Overhead Barbell Press | Barbell Overhead Press | APPROVE_RECOMMENDED | Match: standing barbell overhead press | Match: barbell | Standing unsupported | Bilateral barbell grip at shoulder/chest start | Bar presses vertically from upper chest to overhead lockout | YES | None material | The standing setup and vertical press are clear. |
| FAM-21 | Seated Dumbbell Shoulder Press | Seated Dumbbell Shoulder Press | APPROVE_RECOMMENDED | Match: seated dumbbell shoulder press | Match: dumbbells | Seated with back support | Bilateral dumbbells; neutral-to-pronated grip is harmless | Dumbbells travel from shoulders to overhead and back | YES | Chair rather than adjustable bench is harmless | The seated vertical press and support are visually faithful. |
| FAM-22 | Dumbbell Lateral Raise | Dumbbell Lateral Raise | APPROVE_RECOMMENDED | Match: standing lateral raise | Match: dumbbells | Standing unsupported | Bilateral dumbbells at sides; arms lift laterally | Arms move from sides to roughly shoulder height and lower | YES | None material | The frontal-plane raise and bilateral stance are unambiguous. |
| FAM-23 | Dumbbell Front Raise | Dumbbell Front Raise | APPROVE_RECOMMENDED | Match: standing front raise | Match: dumbbells | Standing unsupported | Bilateral dumbbells with neutral-looking grip | Arms move forward from sides to about shoulder height | YES | None material | The sagittal-plane raise is clear and does not resemble a press. |
| FAM-24 | Face Pulls | Cable Face Pull | APPROVE_RECOMMENDED | Match: standing rope face pull | Match: cable and rope attachment | Standing facing high pulley | Bilateral rope grip with elbows high and externally rotated | Rope travels from extended arms to eye/forehead level | YES | Rope and eye-level target are specific but correct | The elbow path and rope-to-face finish communicate a face pull. |
| FAM-25 | Standing Barbell Curl | Barbell Curl | APPROVE_RECOMMENDED | Match: standing bilateral barbell curl | Match: barbell | Standing unsupported | Bilateral underhand bar grip | Bar moves from thighs to front of shoulders and returns | YES | None material | The standing stance and elbow-flexion range are correct. |
| FAM-26 | Dumbbell Hammer Curl | Dumbbell Hammer Curl | APPROVE_RECOMMENDED | Match: neutral-grip dumbbell curl | Match: dumbbells | Standing unsupported | Bilateral neutral hammer grip | Dumbbells move from sides to shoulders with elbows flexing | YES | None material | The neutral grip and bilateral curl are visually truthful. |
| FAM-27 | Incline Dumbbell Curl | Incline Dumbbell Curl | APPROVE_RECOMMENDED | Match: incline-bench dumbbell curl | Match: dumbbells and incline bench | Seated/reclined on incline bench | Dumbbells hang beside the torso; bilateral presentation is acceptable | Arms extend behind the torso at start and curl toward shoulders | YES | Side view shows one arm prominently | Incline shoulder position and curl direction are clear; the side view does not change the family. |
| FAM-28 | Preacher Curl | Preacher Curl | APPROVE_RECOMMENDED | Match: preacher curl | Match at broad category: barbell-family load; RepDB uses EZ bar | Seated with upper arms supported on preacher pad | EZ-bar grip is a harmless attachment specificity for generic Preacher Curl | Forearms curl from extended over pad toward the chest | YES | EZ bar is more specific than canonical Barbell field | The supported elbow position and curl path are exact; EZ-bar versus straight bar is not material for this unspecialized family. |
| FAM-29 | Tricep Pushdown | Cable Tricep Pushdown | APPROVE_RECOMMENDED | Match: standing cable pushdown | Match: cable and bar attachment | Standing facing high pulley | Bilateral bar/handle grip; elbows stay near sides | Handle travels from bent elbows to straight-arm pushdown | YES | None material | The high-pulley setup and downward elbow-extension direction match. |
| FAM-30 | Skull Crushers (EZ Bar) | Skull Crusher | APPROVE_RECOMMENDED | Match: lying EZ-bar triceps extension | Match: EZ bar and flat bench | Supine on flat bench | Bilateral EZ-bar grip | Elbows flex to bring bar toward forehead and extend to straight arms | YES | None material | The lying position, EZ bar, and forehead-directed range are exact. |
| FAM-31 | Overhead Dumbbell Tricep Extension | Overhead Tricep Extension | APPROVE_RECOMMENDED | Match: overhead dumbbell extension | Match: dumbbell | Standing unsupported | Bilateral hands on one dumbbell; canonical laterality is generic | Dumbbell moves from overhead to behind head and back | YES | One-dumbbell/two-hand presentation is harmless | The overhead elbow-flexion direction and equipment are correct. |
| FAM-32 | Ab Wheel Rollout | Ab Wheel Rollout | APPROVE_RECOMMENDED | Match: kneeling rollout | Match: ab wheel and bodyweight | Kneeling, supported through the wheel | Bilateral hands on wheel; knees remain grounded | Wheel rolls forward into anti-extension and returns | YES | None material | The kneeling setup and anti-extension range are clear. |
| FAM-33 | Cable Crunch | Cable Crunch | APPROVE_RECOMMENDED | Match: kneeling cable crunch | Match: cable and rope | Kneeling facing away from high pulley | Bilateral rope behind neck | Spine flexes downward toward thighs and returns under control | YES | None material | The rope placement and spinal-flexion direction match canonical cues. |
| FAM-34 | Plank | Plank | APPROVE_RECOMMENDED | Match: static forearm plank | Match: bodyweight | Prone, forearms and toes supported, straight body line | Bilateral forearm support; no unrequested variation shown | Static hold; no START/PEAK pair is required | YES | MAIN-only artwork | The MAIN image is a truthful canonical forearm plank and does not claim tempo or pause behavior. |
| FAM-35 | Hanging Leg Raise | Hanging Leg Raise | REJECT_RECOMMENDED | No match: image shows bent-knee hanging knee raise | Match: bodyweight pull-up bar | Hanging unsupported from bar, but knees are flexed | Bilateral overhand grip; the material issue is lower-limb configuration | Image raises flexed knees rather than straight legs to the canonical 90-degree target | NO | Bent-knee versus straight-leg identity/range | The canonical catalog cue requires hanging with straight legs raised to 90 degrees; this candidate depicts a regression/related knee raise and would mislead. |

## Counts

| Recommendation | Count |
|---|---:|
| APPROVE_RECOMMENDED | 30 |
| REJECT_RECOMMENDED | 4 |
| NEEDS_HUMAN_REVIEW | 1 |
| Total families reviewed | 35 |

## Highest-risk mappings

- **FAM-03 — Decline Hammer Strength Press:** explicit `NO_MATCH`; do not substitute generic decline barbell or generic machine artwork.
- **FAM-17 — Seated Leg Curl:** prone/lying apparatus is a material body-orientation and setup mismatch.
- **FAM-18 — Standing Calf Raise:** the actual canonical equipment is Bodyweight, while the image prominently depicts a loaded standing calf machine.
- **FAM-35 — Hanging Leg Raise:** canonical cues require straight legs to 90 degrees; the image is a bent-knee hanging knee raise.
- **FAM-19 — Walking Lunges:** a static forward-lunge pair may be sufficient for one step, but the image does not establish continuous walking or alternation; human product judgment is required.
- **FAM-12 — Seated Cable Row:** wide straight-bar attachment is acceptable under the unspecialized canonical name, but this is the main approved mapping with a meaningful grip/attachment caveat.

## Candidate-confidence disagreements

### Flash over-rated

- **FAM-18:** labeled `EXACT`, but the canonical catalog says Bodyweight and the actual image is a loaded machine calf raise. This is a material equipment mismatch.
- **FAM-35:** labeled `EXACT`, but the actual image shows flexed knees while the canonical cues require straight-leg hanging raises to 90 degrees. This is a material movement/range mismatch.
- **FAM-19:** labeled `STRONG`; the equipment and lunge pose are strong, but the label overstates equivalence because locomotion is not visually established. I recommend human review.
- **FAM-28:** labeled `EXACT`; the movement is visually truthful, but “exact” overstates attachment equality because the RepDB image uses an EZ bar against the broad canonical Barbell field. The difference is harmless here, so the family remains approve-recommended.

### Flash under-rated

No clear under-rated candidate was found after image inspection. `FAM-03 NO_MATCH` and `FAM-17 AMBIGUOUS` were appropriately cautious. The other `STRONG` and `EXACT` candidates that I approve are visually defensible, subject to human approval still being required.

## Validation and scope confirmation

- All 35 families were reviewed individually from the actual pinned review image files or the explicit FAM-03 no-candidate state.
- All proposed technique-variant reuse decisions preserve the 140 canonical UUID identities; no identity merge is recommended.
- The original `R08_0_2_REPDB_MAPPING_REVIEW.csv` remains unchanged and all official `visual_review_status` values remain `PENDING`.
- No production code, `assets/third_party/asset_manifest.json`, B02 taxonomy, `ExerciseDisplayMuscles`, B05 registry, or production asset root was modified.
- Production RepDB asset count remains zero under `assets/exercises/repdb/`.
- No production media integration, vendor operation, automatic approval, openGym code/media reuse, or physical-device testing was performed.

