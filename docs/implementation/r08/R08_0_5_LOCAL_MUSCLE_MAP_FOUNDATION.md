# R08-0.5 Local IndiFit Muscle Map Foundation

## Scope

R08-0.5 adds an isolated, local Flutter anatomy renderer foundation. It is a
presentation primitive for future product work; it is not integrated into
Progress, Training, Exercise Detail, Workout Player, persistence, or media
approval.

The local renderer consumes canonical/display muscle concepts in exercise mode
or caller-supplied intensity values in heat mode. B02 remains authoritative for
analytical muscle allocation. Upstream MuscleMap geometry is never written back
to IndiFit taxonomy or exercise data.

## Architecture

    ExerciseDisplayMuscles / explicit caller values
            ↓
    IndiFitMuscleMapTaxonomyAdapter
            ↓
    presentation highlight or heat resolution
            ↓
    generated local geometry registry
            ↓
    static Flutter CustomPainter
            ↓
    semantic/text equivalent

IndiFitMuscleMap supports male/female and front/back/both views. Geometry is
loaded from generated Dart path commands. The painter preserves each source
view box aspect ratio, centers the drawing without clipping, and uses semantic
B05 theme roles for inactive, primary, secondary, outline, and heat states.

Exercise mode uses a solid primary treatment and a patterned secondary
treatment so the distinction is not dependent on subtle hue differences. Heat
mode paints only supplied, explicitly resolved values. Missing concepts remain
neutral; unknown concepts remain unresolved; no-data is never represented as
measured zero.

The default component is static and has no animation. Its semantics contain a
canonical muscle/value description, while the visible text equivalent remains
available beneath the graphic. The isolated
IndiFitMuscleMapShowcase demonstrates representative states without adding
consumer navigation.

## Complete accepted presentation mapping

Matching is case-insensitive with whitespace normalization and otherwise exact.
There is no substring or fuzzy fallback. The right-hand values are pinned local
geometry slugs, not IndiFit canonical muscle IDs.

| Exact display concepts | Local geometry regions |
| --- | --- |
| Chest | chest, upper-chest, lower-chest |
| Back | upper-back, lower-back, trapezius |
| Shoulders | deltoids, front-deltoid |
| Biceps | biceps |
| Triceps | triceps |
| Quadriceps, Legs | quadriceps, inner-quad, outer-quad |
| Hamstrings | hamstring |
| Glutes, Gluteus Maximus, glute-maximus | gluteal |
| Calves | calves |
| Core | abs, obliques |

The current four-entry B02 catalog (chest, glute-maximus, quadriceps, triceps)
is not expanded by this table. Its IDs are accepted only through the explicit
presentation aliases shown above.

The remaining accepted concepts are the exact current values in
`Exercises.muscleGroups`. Upstream-only anatomy labels are not input aliases.
In particular, Abs/Abdominals, Calf, Deltoids, Feet, Forearm(s), Hamstring,
Hip flexors, Lower/Upper back, Neck, Obliques, Quads, Rear deltoids,
Rhomboids, Rotator cuff, and Traps/Trapezius remain unresolved until an IndiFit
presentation source actually emits them. Several of the previously reported
targets also had no path in the pinned registry, so accepting them would have
created illusory compatibility.

Broad concepts are visual decompositions only. `Back` uses all currently
available broad back geometry; `Shoulders` uses front and back `deltoids` plus
the available front-deltoid detail. `Legs` retains IndiFit's existing
quad-dominant exercise-category meaning rather than defining a general anatomy
term. `Core` paints abs and obliques but does not divide or duplicate analytical
allocation. In heat mode, the caller owns each supplied value; copying that
value to the visual subregions is a painting choice, not a B02 contribution.

## Review limitations

- MuscleMap's upstream regions are visual anatomy labels, not equipment,
  exercise, or IndiFit taxonomy.
- The renderer cannot express exercise-specific equipment or technique; those
  facts remain owned by canonical exercise data and cues.
- Upstream region granularity differs by body model and view. An absent
  region is left neutral rather than invented.
- No stabilizer or physiological heat metric is inferred.
- The generated geometry is static and local; no runtime MuscleMap source,
  hosted Anatome dependency, or external taxonomy service is used.

## Boundary confirmations

- Existing B05 logical visual-registry and text-fallback contracts were not
  changed.
- B02 taxonomy, mappings, exercise IDs, and database models were not changed.
- No production Progress, Training, Exercise Detail, or Workout Player layout
  was changed.
- assets/third_party/asset_manifest.json and RepDB approval mappings were not
  changed.
