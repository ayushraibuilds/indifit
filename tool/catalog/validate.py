#!/usr/bin/env python3
"""Validates the food catalogue packs (CAT-5). Exits non-zero on any violation.

Invariants (NUTRITION_CATALOGUE_PACKS_PLAN.md § 5):
  format            the pack parses as CAT-1 (what catalog_pack.dart accepts)
  unique-id         food ids are unique
  id-disappeared    no id of the previous pack disappears without a retirement
  retirement        a retired id exists and its replacement is an active food
  energy            every active food has energy
  atwater           kcal within ±25 % of 4P + 4C + 9F (fibre may count 2 kcal/g)
  serving-grams     every serving amount and gram weight is > 0
  household-amount  a household unit (katori, piece, …) is at most 6 per serving
  household-grams   a gram weight matches its unit's rule in overlays/
  variant-ratio     a variant's kcal per gram (per unit when neither side has
                    grams) is within ±25 % of its base, unless tagged size/oil
  retired-name      names of retired foods never return as active foods
  size-budget       a full pack is under 1 MB gzipped
  stale             the committed packs equal what build.py produces

Usage:
    python3 tool/catalog/validate.py              # the built packs (CI)
    python3 tool/catalog/validate.py --baseline   # today's data, before the
                                                  # overlay fixes (shows the
                                                  # invariants bite)
"""

import json
import sys
from collections import Counter, namedtuple
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build  # noqa: E402

Violation = namedtuple("Violation", "rule food_id name detail")

HOUSEHOLD_MAX = 6
RATIO_TOLERANCE = 0.25
ATWATER_TOLERANCE = 0.25
# Low-energy foods (black coffee, 2 kcal) can't meet a relative bound, so the
# Atwater check also allows this many kcal per fact basis either way.
ATWATER_SLACK_KCAL = 10
SIZE_BUDGET_BYTES = 1_000_000
METRIC_UNITS = {"g", "ml"}
EXEMPT_TAGS = {"size", "oil"}


def _norm(text):
    return " ".join(text.split()).lower()


def _kcal_per(food):
    """(kcal per gram, kcal per unit, unit) of a food's default serving."""
    serving = next(s for s in food["servings"] if s.get("default"))
    energy = food["facts"]["values"].get("energy")
    if energy is None:
        return None, None, None
    basis = food["facts"]["basis"]
    grams = serving.get("grams")
    if basis == "per_100_grams":
        per_serving = energy * serving["grams"] / 100
    elif basis == "per_100_millilitres":
        per_serving = energy * serving["amount"] / 100
    else:
        per_serving = energy
    per_gram = per_serving / grams if grams else None
    per_unit = per_serving / serving["amount"]
    return per_gram, per_unit, serving["unit"]


def check_format(pack, nutrient_ids):
    out = []
    if pack.get("format") != build.FORMAT:
        out.append(Violation("format", None, None, f"format {pack.get('format')}"))
    if pack.get("kind") not in ("full", "delta"):
        out.append(Violation("format", None, None, f"kind {pack.get('kind')}"))
    sources = {source["id"] for source in pack.get("sources", [])}
    for food in pack.get("foods", []):
        fid, name = food.get("id"), food.get("display_name")

        def bad(detail, fid=fid, name=name):
            out.append(Violation("format", fid, name, detail))

        if not fid or not str(name or "").strip():
            bad("needs an id and a display name")
        if food.get("source_id") not in sources:
            bad(f"unknown source {food.get('source_id')}")
        facts = food.get("facts") or {}
        if facts.get("basis") not in ("per_100_grams", "per_100_millilitres", "per_serving"):
            bad(f"basis {facts.get('basis')}")
        for key, value in (facts.get("values") or {}).items():
            if key not in nutrient_ids:
                bad(f"unknown nutrient {key}")
            if not isinstance(value, (int, float)) or value < 0:
                bad(f"{key} = {value!r}")
        defaults = [s for s in food.get("servings", []) if s.get("default")]
        if len(defaults) != 1:
            bad("needs exactly one default serving")
        elif facts.get("basis") == "per_100_grams" and not defaults[0].get("grams"):
            bad("per 100 g, so the default serving needs grams")
        for alias in food.get("aliases", []):
            if not str(alias.get("text", "")).strip() or not alias.get("locale"):
                bad(f"alias {alias!r}")
    return out


def check_pack(pack, previous=None, retired_names=(), gram_rules=None, nutrient_ids=None):
    """Every invariant that can be checked on one full pack."""
    out = []
    if nutrient_ids is not None:
        out += check_format(pack, nutrient_ids)
    foods = pack["foods"]
    by_id = {}
    for food in foods:
        if food["id"] in by_id:
            out.append(Violation("unique-id", food["id"], food["display_name"], "repeats"))
        by_id[food["id"]] = food
    retired = {entry["id"]: entry.get("replaced_by") for entry in pack["retire"]}

    def active(food):
        return food["id"] not in retired and food.get("lifecycle", "active") == "active"

    if previous is not None:
        for food in previous["foods"]:
            if food["id"] not in by_id and food["id"] not in retired:
                out.append(
                    Violation(
                        "id-disappeared",
                        food["id"],
                        food["display_name"],
                        f"in v{previous['version']} but neither a food nor retired",
                    )
                )
    for fid, replacement in retired.items():
        if fid not in by_id:
            out.append(Violation("retirement", fid, None, "retired id is not in the pack"))
        if replacement is not None and (
            replacement not in by_id or not active(by_id[replacement])
        ):
            out.append(
                Violation(
                    "retirement",
                    fid,
                    by_id.get(fid, {}).get("display_name"),
                    f"replaced_by {replacement} is not an active food",
                )
            )
        if by_id.get(fid, {}).get("lifecycle", "deprecated") != "deprecated":
            out.append(
                Violation("retirement", fid, by_id[fid]["display_name"], "lifecycle is not deprecated")
            )

    rules = gram_rules or {}
    for food in foods:
        if not active(food):
            continue
        fid, name = food["id"], food["display_name"]
        values = food["facts"]["values"]
        energy = values.get("energy")
        if energy is None:
            out.append(Violation("energy", fid, name, "no energy"))
            continue
        p, c, f = (values.get(k, 0) for k in ("protein", "carbohydrate", "fat"))
        fibre = min(values.get("fibre", 0), c)
        alcohol = values.get("alcohol", 0)
        high = 4 * p + 4 * c + 9 * f + 7 * alcohol
        low = 4 * p + 4 * (c - fibre) + 2 * fibre + 9 * f + 7 * alcohol
        if not (
            low * (1 - ATWATER_TOLERANCE) - ATWATER_SLACK_KCAL
            <= energy
            <= high * (1 + ATWATER_TOLERANCE) + ATWATER_SLACK_KCAL
        ):
            out.append(
                Violation("atwater", fid, name, f"{energy:g} kcal vs {low:.0f}–{high:.0f} from macros")
            )
        for serving in food["servings"]:
            grams = serving.get("grams")
            if not serving.get("amount") or serving["amount"] <= 0:
                out.append(Violation("serving-grams", fid, name, f"amount {serving.get('amount')}"))
            if grams is not None and grams <= 0:
                out.append(Violation("serving-grams", fid, name, f"grams {grams}"))
            unit = serving["unit"]
            if unit not in METRIC_UNITS and serving["amount"] > HOUSEHOLD_MAX:
                out.append(
                    Violation(
                        "household-amount",
                        fid,
                        name,
                        f"{serving['amount']:g} {unit} per serving (max {HOUSEHOLD_MAX})",
                    )
                )
            rule = rules.get(unit)
            if grams is not None and unit not in METRIC_UNITS:
                expected = None if rule is None else serving["amount"] * rule["grams_per_unit"]
                if expected is None or abs(grams - expected) > 0.01 * expected:
                    out.append(
                        Violation(
                            "household-grams",
                            fid,
                            name,
                            f"{grams:g} g for {serving['amount']:g} {unit}"
                            + ("" if expected is None else f", rule says {expected:g} g"),
                        )
                    )

        base_id = food.get("variant_of")
        if base_id is None or EXEMPT_TAGS & set(food.get("tags", [])):
            continue
        base = by_id.get(base_id)
        if base is None:
            out.append(Violation("variant-ratio", fid, name, f"base {base_id} missing"))
            continue
        v_gram, v_unit, v_measure = _kcal_per(food)
        b_gram, b_unit, b_measure = _kcal_per(base)
        if v_gram is not None and b_gram is not None:
            ratio, per = v_gram / b_gram if b_gram else None, "gram"
        elif v_measure == b_measure and v_measure not in METRIC_UNITS:
            ratio, per = v_unit / b_unit if b_unit else None, v_measure
        else:
            continue  # no shared measure: nothing honest to compare
        if ratio is not None and abs(ratio - 1) > RATIO_TOLERANCE:
            out.append(
                Violation(
                    "variant-ratio",
                    fid,
                    name,
                    f"{ratio:.2f}x the kcal per {per} of {base['display_name']!r}",
                )
            )

    names = set(retired_names)
    names |= {_norm(by_id[fid]["display_name"]) for fid in retired if fid in by_id}
    for food in foods:
        if active(food) and _norm(food["display_name"]) in names:
            out.append(Violation("retired-name", food["id"], food["display_name"], "a retired name returned"))
    return out


def check_delta(previous, delta, full):
    """Applying [delta] to [previous] must give [full]."""
    out = []
    if delta["base"] != previous["version"] or delta["version"] != full["version"]:
        out.append(Violation("delta", None, None, "base or version mismatch"))
    foods = {food["id"]: food for food in previous["foods"]}
    foods.update({food["id"]: food for food in delta["foods"]})
    if foods != {food["id"]: food for food in full["foods"]}:
        out.append(Violation("delta", None, None, f"v{delta['base']} + delta != v{full['version']} foods"))
    retired = {r["id"]: r for r in previous["retire"]}
    retired.update({r["id"]: r for r in delta["retire"]})
    if retired != {r["id"]: r for r in full["retire"]}:
        out.append(Violation("delta", None, None, "retirements differ from the full pack"))
    return out


def _gram_rules(version):
    rules = {}
    for _, data in build.load_overlays(version):
        for rule in data.get("rules") or []:
            rules[rule["unit"]] = rule
    return rules


def _nutrient_ids():
    registry = json.loads(build.REGISTRY.read_text(encoding="utf-8"))
    return {nutrient["id"] for nutrient in registry["nutrients"]}


def validate_built():
    """The committed outputs: fresh, and the latest pack clean."""
    out = []
    outputs, packs = build.build_outputs()
    stale, extra = build.stale_outputs(outputs)
    for path in stale + extra:
        out.append(Violation("stale", None, None, f"{path.relative_to(build.ROOT)}: run build.py"))
    latest = packs[build.LATEST]
    previous = packs.get(build.LATEST - 1)
    history = set()
    for version in range(2, build.LATEST):
        pack = packs[version]
        by_id = {food["id"]: food for food in pack["foods"]}
        history |= {_norm(by_id[r["id"]]["display_name"]) for r in pack["retire"]}
    out += check_pack(
        latest,
        previous=previous,
        retired_names=history,
        gram_rules=_gram_rules(build.LATEST),
        nutrient_ids=_nutrient_ids(),
    )
    if previous is not None:
        delta = build.decode(outputs[build.PACKS / f"v{build.LATEST}/{build.LATEST}-from-{build.LATEST - 1}.json.gz"])
        out += check_delta(previous, delta, latest)
    size = len(outputs[build.PACKS / f"v{build.LATEST}/{build.LATEST}.json.gz"])
    if size >= SIZE_BUDGET_BYTES:
        out.append(Violation("size-budget", None, None, f"{size} bytes"))
    return out


def validate_baseline():
    """Today's catalogue described in the pack format, before any fix."""
    pack = build.build_pack(build.LATEST, apply_fixes=False)
    return check_pack(pack, gram_rules=_gram_rules(build.LATEST))


def report(violations, out=None):
    out = out or sys.stdout
    if not violations:
        print("No violations.", file=out)
        return
    counts = Counter(v.rule for v in violations)
    for rule in sorted(counts):
        print(f"\n{rule}: {counts[rule]}", file=out)
        for v in (v for v in violations if v.rule == rule):
            label = f"{v.food_id} {v.name!r}" if v.food_id else "-"
            print(f"  {label}: {v.detail}", file=out)
    total = ", ".join(f"{rule} {count}" for rule, count in sorted(counts.items()))
    print(f"\n{len(violations)} violations ({total})", file=out)


def main(argv):
    try:
        violations = validate_baseline() if "--baseline" in argv else validate_built()
    except build.BuildError as error:
        print(f"validate.py: {error}")
        return 1
    report(violations)
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
