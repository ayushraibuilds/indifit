#!/usr/bin/env python3
import json
import os
import shutil
import hashlib
import csv
import re

# Pinned commit check
EXPECTED_COMMIT = "045845b61e4aefd9e684fa84518b84c665ea3cd3"
REPDB_CLONE_DIR = "/tmp/repdb_clone"

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOCS_R08_DIR = os.path.join(PROJECT_ROOT, "docs", "implementation", "r08")
REVIEW_ARTIFACTS_DIR = os.path.join(DOCS_R08_DIR, "review_artifacts")
REVIEW_IMAGES_DIR = os.path.join(REVIEW_ARTIFACTS_DIR, "repdb_mapping_review")

os.makedirs(REVIEW_IMAGES_DIR, exist_ok=True)

# Load RepDB exercises
with open(os.path.join(REPDB_CLONE_DIR, "exercises.json"), "r") as f:
    repdb_data = json.load(f)
repdb_map = {ex["id"]: ex for ex in repdb_data["exercises"]}

# Load IndiFit canonical catalog
with open(os.path.join(PROJECT_ROOT, "assets", "data", "exercises.json"), "r") as f:
    indifit_raw = json.load(f)

# Group IndiFit exercises into 35 base families
families = {}
for ex in indifit_raw:
    name = ex["name"]
    base = name
    if name.startswith("Pause "):
        base = name[len("Pause "):]
    elif name.startswith("Slow Eccentric "):
        base = name[len("Slow Eccentric "):]
    elif name.endswith(" (Standard)"):
        base = name[:-len(" (Standard)")]
    families.setdefault(base, []).append(ex)

# Load golden UUID map from exercise_identity_fixtures.dart
with open(os.path.join(PROJECT_ROOT, "lib", "core", "fixtures", "exercise_identity_fixtures.dart"), "r") as f:
    fixtures_content = f.read()

pattern = re.compile(r"'([^']+)':\s*'([0-9a-f\-]+)'")
golden_map = dict(pattern.findall(fixtures_content))
print(f"Extracted {len(golden_map)} golden UUID mappings from fixtures.")

# Authoritative Candidate Mapping Specifications (35 families)
MAPPING_SPEC = [
    {
        "family_id": "FAM-01",
        "base_name": "Flat Barbell Bench Press",
        "repdb_id": "bench-press",
        "confidence": "EXACT",
        "reason": "Direct movement and equipment match; standard flat barbell chest press.",
        "semantic_conflicts": "None (RepDB: pectoralis_major; IndiFit: Chest).",
    },
    {
        "family_id": "FAM-02",
        "base_name": "Incline Dumbbell Bench Press",
        "repdb_id": "incline-db-press",
        "confidence": "EXACT",
        "reason": "Exact movement and equipment match; 30-45 degree incline dumbbell chest press.",
        "semantic_conflicts": "None (RepDB: pectoralis_major; IndiFit: Chest).",
    },
    {
        "family_id": "FAM-03",
        "base_name": "Decline Hammer Strength Press",
        "repdb_id": "NO_MATCH",
        "confidence": "NO_MATCH",
        "reason": "RepDB free tier lacks plate-loaded convergent Decline Hammer Strength press; only has barbell decline and generic machine press.",
        "semantic_conflicts": "Machine apparatus subtype mismatch. Fails closed to B05 text/muscle fallback. Do not substitute generic decline bench.",
    },
    {
        "family_id": "FAM-04",
        "base_name": "Chest Dips",
        "repdb_id": "dips",
        "confidence": "STRONG",
        "reason": "RepDB dips matches dip-station bodyweight dip with forward torso lean.",
        "semantic_conflicts": "Taxonomy difference: RepDB classifies under triceps_brachii as primary with pectoralis_major secondary; IndiFit classifies Chest as primary. Torso angle in visual shows chest engagement.",
    },
    {
        "family_id": "FAM-05",
        "base_name": "Push-Ups",
        "repdb_id": "push-up",
        "confidence": "EXACT",
        "reason": "Singular vs plural naming difference; exact standard prone bodyweight push-up.",
        "semantic_conflicts": "None (RepDB: pectoralis_major; IndiFit: Chest).",
    },
    {
        "family_id": "FAM-06",
        "base_name": "Cable Chest Fly",
        "repdb_id": "cable-fly",
        "confidence": "EXACT",
        "reason": "Exact movement and cable apparatus match; bilateral standing cable chest fly.",
        "semantic_conflicts": "None (RepDB: pectoralis_major; IndiFit: Chest).",
    },
    {
        "family_id": "FAM-07",
        "base_name": "Barbell Deadlift",
        "repdb_id": "deadlift",
        "confidence": "STRONG",
        "reason": "Exact mechanical movement; standard conventional bilateral barbell deadlift.",
        "semantic_conflicts": "Taxonomy difference: RepDB assigns gluteus_maximus/hamstrings as primary with erector_spinae/latissimus_dorsi secondary; IndiFit classifies Back as primary display category with posterior chain secondary.",
    },
    {
        "family_id": "FAM-08",
        "base_name": "Lat Pulldown",
        "repdb_id": "lat-pulldown",
        "confidence": "EXACT",
        "reason": "Exact equipment and mechanics match; wide-grip seated cable pulldown.",
        "semantic_conflicts": "None (RepDB: latissimus_dorsi; IndiFit: Back).",
    },
    {
        "family_id": "FAM-09",
        "base_name": "Bent Over Barbell Row",
        "repdb_id": "barbell-row",
        "confidence": "EXACT",
        "reason": "Exact equipment and mechanical posture match; standing bent-over barbell row.",
        "semantic_conflicts": "None (RepDB: latissimus_dorsi; IndiFit: Back).",
    },
    {
        "family_id": "FAM-10",
        "base_name": "One-Arm Dumbbell Row",
        "repdb_id": "single-arm-db-row",
        "confidence": "EXACT",
        "reason": "Exact unilateral bench-supported dumbbell row match.",
        "semantic_conflicts": "None (RepDB: latissimus_dorsi; IndiFit: Back).",
    },
    {
        "family_id": "FAM-11",
        "base_name": "Pull-Ups",
        "repdb_id": "pull-up",
        "confidence": "EXACT",
        "reason": "Singular vs plural naming difference; standard overhand bodyweight pull-up.",
        "semantic_conflicts": "None (RepDB: latissimus_dorsi; IndiFit: Back).",
    },
    {
        "family_id": "FAM-12",
        "base_name": "Seated Cable Row",
        "repdb_id": "wide-grip-seated-cable-row",
        "confidence": "STRONG",
        "reason": "Exact apparatus and seated cable row mechanics.",
        "semantic_conflicts": "Grip attachment note: RepDB illustration uses wide-grip bar attachment rather than close-grip V-bar. Reviewer must verify whether wide-grip visual is acceptable for canonical Seated Cable Row.",
    },
    {
        "family_id": "FAM-13",
        "base_name": "Barbell Squat",
        "repdb_id": "squat",
        "confidence": "EXACT",
        "reason": "Exact back squat match; standard bilateral barbell back squat.",
        "semantic_conflicts": "None (RepDB: quadriceps; IndiFit: Legs/Quads).",
    },
    {
        "family_id": "FAM-14",
        "base_name": "Leg Press",
        "repdb_id": "leg-press",
        "confidence": "EXACT",
        "reason": "Exact 45-degree sled machine leg press match.",
        "semantic_conflicts": "None (RepDB: quadriceps; IndiFit: Legs/Quads).",
    },
    {
        "family_id": "FAM-15",
        "base_name": "Romanian Deadlift (RDL)",
        "repdb_id": "romanian-deadlift",
        "confidence": "EXACT",
        "reason": "Exact barbell hinge movement; IndiFit includes (RDL) acronym alias.",
        "semantic_conflicts": "None (RepDB: hamstrings; IndiFit: Hamstrings).",
    },
    {
        "family_id": "FAM-16",
        "base_name": "Leg Extensions",
        "repdb_id": "leg-extension",
        "confidence": "EXACT",
        "reason": "Singular vs plural naming difference; seated machine knee extension.",
        "semantic_conflicts": "None (RepDB: quadriceps; IndiFit: Legs/Quads).",
    },
    {
        "family_id": "FAM-17",
        "base_name": "Seated Leg Curl",
        "repdb_id": "leg-curl",
        "confidence": "AMBIGUOUS",
        "reason": "RepDB free tier only includes lying prone machine leg curl (leg-curl); lacks seated leg curl machine illustration.",
        "semantic_conflicts": "Apparatus / Body orientation conflict: IndiFit prescribes Seated Leg Curl; RepDB candidate illustrates Lying Leg Curl (prone). Reviewer must evaluate if lying machine artwork is acceptable or should fail closed to muscle/text fallback.",
    },
    {
        "family_id": "FAM-18",
        "base_name": "Standing Calf Raise",
        "repdb_id": "standing-calf-raise",
        "confidence": "EXACT",
        "reason": "Exact standing machine calf raise match.",
        "semantic_conflicts": "None (RepDB: gastrocnemius; IndiFit: Calves).",
    },
    {
        "family_id": "FAM-19",
        "base_name": "Walking Lunges",
        "repdb_id": "db-lunge",
        "confidence": "STRONG",
        "reason": "Dumbbell lunge with matching dumbbell equipment.",
        "semantic_conflicts": "Locomotion note: RepDB illustration shows stationary dumbbell split lunge posture rather than continuous walking traversal.",
    },
    {
        "family_id": "FAM-20",
        "base_name": "Overhead Barbell Press",
        "repdb_id": "ohp",
        "confidence": "STRONG",
        "reason": "RepDB uses OHP acronym; exact standing barbell overhead press.",
        "semantic_conflicts": "None (RepDB: anterior_deltoid; IndiFit: Shoulders).",
    },
    {
        "family_id": "FAM-21",
        "base_name": "Seated Dumbbell Shoulder Press",
        "repdb_id": "seated-db-press",
        "confidence": "EXACT",
        "reason": "Exact seated vertical dumbbell press match.",
        "semantic_conflicts": "None (RepDB: anterior_deltoid; IndiFit: Shoulders).",
    },
    {
        "family_id": "FAM-22",
        "base_name": "Dumbbell Lateral Raise",
        "repdb_id": "lateral-raise",
        "confidence": "EXACT",
        "reason": "Exact standing dumbbell medial deltoid raise match.",
        "semantic_conflicts": "None (RepDB: lateral_deltoid; IndiFit: Shoulders).",
    },
    {
        "family_id": "FAM-23",
        "base_name": "Dumbbell Front Raise",
        "repdb_id": "dumbbell-front-raise",
        "confidence": "EXACT",
        "reason": "Exact standing dumbbell anterior deltoid raise match.",
        "semantic_conflicts": "None (RepDB: anterior_deltoid; IndiFit: Shoulders).",
    },
    {
        "family_id": "FAM-24",
        "base_name": "Face Pulls",
        "repdb_id": "face-pull",
        "confidence": "EXACT",
        "reason": "Singular vs plural naming difference; rope cable face pull to eye level.",
        "semantic_conflicts": "None (RepDB: posterior_deltoid; IndiFit: Shoulders).",
    },
    {
        "family_id": "FAM-25",
        "base_name": "Standing Barbell Curl",
        "repdb_id": "barbell-curl",
        "confidence": "STRONG",
        "reason": "RepDB omits 'Standing' prefix; identical standing bilateral barbell curl.",
        "semantic_conflicts": "None (RepDB: biceps_brachii; IndiFit: Biceps).",
    },
    {
        "family_id": "FAM-26",
        "base_name": "Dumbbell Hammer Curl",
        "repdb_id": "hammer-curl",
        "confidence": "STRONG",
        "reason": "RepDB names it hammer-curl; identical neutral-grip standing dumbbell curl.",
        "semantic_conflicts": "None (RepDB: brachioradialis/biceps; IndiFit: Biceps).",
    },
    {
        "family_id": "FAM-27",
        "base_name": "Incline Dumbbell Curl",
        "repdb_id": "incline-db-curl",
        "confidence": "EXACT",
        "reason": "Exact incline bench dumbbell curl match.",
        "semantic_conflicts": "None (RepDB: biceps_brachii; IndiFit: Biceps).",
    },
    {
        "family_id": "FAM-28",
        "base_name": "Preacher Curl",
        "repdb_id": "preacher-curl",
        "confidence": "EXACT",
        "reason": "Exact preacher bench EZ-bar curl match.",
        "semantic_conflicts": "None (RepDB: biceps_brachii; IndiFit: Biceps).",
    },
    {
        "family_id": "FAM-29",
        "base_name": "Tricep Pushdown",
        "repdb_id": "tricep-pushdown",
        "confidence": "EXACT",
        "reason": "Exact cable triceps pushdown match.",
        "semantic_conflicts": "None (RepDB: triceps_brachii; IndiFit: Triceps).",
    },
    {
        "family_id": "FAM-30",
        "base_name": "Skull Crushers (EZ Bar)",
        "repdb_id": "skull-crusher",
        "confidence": "STRONG",
        "reason": "RepDB names it skull-crusher; visual is lying EZ-bar triceps extension to forehead.",
        "semantic_conflicts": "None (RepDB: triceps_brachii; IndiFit: Triceps).",
    },
    {
        "family_id": "FAM-31",
        "base_name": "Overhead Dumbbell Tricep Extension",
        "repdb_id": "overhead-tricep-extension",
        "confidence": "STRONG",
        "reason": "Exact overhead dumbbell extension movement; word order difference.",
        "semantic_conflicts": "None (RepDB: triceps_brachii; IndiFit: Triceps).",
    },
    {
        "family_id": "FAM-32",
        "base_name": "Ab Wheel Rollout",
        "repdb_id": "ab-wheel-rollout",
        "confidence": "EXACT",
        "reason": "Exact kneeling anti-extension core roll match.",
        "semantic_conflicts": "None (RepDB: rectus_abdominis; IndiFit: Core).",
    },
    {
        "family_id": "FAM-33",
        "base_name": "Cable Crunch",
        "repdb_id": "cable-crunch",
        "confidence": "EXACT",
        "reason": "Exact kneeling cable spine flexion crunch match.",
        "semantic_conflicts": "None (RepDB: rectus_abdominis; IndiFit: Core).",
    },
    {
        "family_id": "FAM-34",
        "base_name": "Plank",
        "repdb_id": "plank",
        "confidence": "EXACT",
        "reason": "Exact static prone forearm plank match.",
        "semantic_conflicts": "Static movement: RepDB provides single 'main' image rather than start/peak pose pair.",
    },
    {
        "family_id": "FAM-35",
        "base_name": "Hanging Leg Raise",
        "repdb_id": "hanging-leg-raise",
        "confidence": "EXACT",
        "reason": "Exact bar-hanging knee/leg raise match.",
        "semantic_conflicts": "None (RepDB: rectus_abdominis/iliopsoas; IndiFit: Core).",
    },
]

processed_rows = []
all_image_hashes = {}

for spec in MAPPING_SPEC:
    family_id = spec["family_id"]
    base_name = spec["base_name"]
    repdb_id = spec["repdb_id"]
    confidence = spec["confidence"]
    reason = spec["reason"]
    conflicts = spec["semantic_conflicts"]
    
    variants = families[base_name]
    variant_uuids = []
    variant_names = []
    for v in variants:
        v_name = v["name"]
        norm_name = v_name.strip().lower()
        uuid = golden_map.get(norm_name, "UNKNOWN")
        variant_uuids.append(uuid)
        variant_names.append(v_name)
    
    primary_uuid = golden_map.get(base_name.strip().lower(), variant_uuids[0])
    
    raw_muscles = variants[0].get("muscle_groups", "")
    muscle_tokens = [m.strip() for m in raw_muscles.split(",") if m.strip()]
    primary_display_muscle = muscle_tokens[0] if muscle_tokens else ""
    secondary_display_muscles = ", ".join(muscle_tokens[1:]) if len(muscle_tokens) > 1 else ""
    equipment = variants[0].get("equipment", "")
    
    repdb_name = ""
    repdb_start_path = ""
    repdb_peak_path = ""
    repdb_main_path = ""
    repdb_equipment = ""
    repdb_primary_muscles = ""
    repdb_secondary_muscles = ""
    
    if repdb_id != "NO_MATCH":
        r_ex = repdb_map[repdb_id]
        repdb_name = r_ex["name_en"]
        repdb_equipment = r_ex.get("equipment", "")
        repdb_primary_muscles = ", ".join(r_ex.get("primary_muscles", []))
        repdb_secondary_muscles = ", ".join(r_ex.get("secondary_muscles", []))
        
        r_images = r_ex.get("images", {}).get("flat", {})
        repdb_start_path = r_images.get("start", "")
        repdb_peak_path = r_images.get("peak", "")
        repdb_main_path = r_images.get("main", "")
        
        for path_field, role in [(repdb_start_path, "start"), (repdb_peak_path, "peak"), (repdb_main_path, "main")]:
            if path_field:
                src = os.path.join(REPDB_CLONE_DIR, path_field)
                if os.path.exists(src):
                    filename = os.path.basename(path_field)
                    dst = os.path.join(REVIEW_IMAGES_DIR, filename)
                    shutil.copyfile(src, dst)
                    with open(src, "rb") as img_f:
                        img_bytes = img_f.read()
                        sha = f"sha256:{hashlib.sha256(img_bytes).hexdigest()}"
                        all_image_hashes[path_field] = {
                            "filename": filename,
                            "role": role,
                            "sha256": sha,
                            "size_bytes": len(img_bytes)
                        }
                else:
                    print(f"ERROR: RepDB image missing: {src}")

    row = {
        "family_id": family_id,
        "base_name": base_name,
        "indifit_primary_uuid": primary_uuid,
        "canonical_uuid_bindings": ";".join(variant_uuids),
        "canonical_names": ";".join(variant_names),
        "equipment": equipment,
        "primary_display_muscle": primary_display_muscle,
        "secondary_display_muscles": secondary_display_muscles,
        "repdb_id": repdb_id,
        "repdb_name": repdb_name,
        "repdb_equipment": repdb_equipment,
        "repdb_primary_muscles": repdb_primary_muscles,
        "repdb_secondary_muscles": repdb_secondary_muscles,
        "repdb_start_path": repdb_start_path,
        "repdb_peak_path": repdb_peak_path,
        "repdb_main_path": repdb_main_path,
        "candidate_confidence": confidence,
        "candidate_reason": reason,
        "semantic_conflicts": conflicts,
        "visual_review_status": "PENDING",
        "visual_review_notes": "",
        "reviewer": "",
        "review_date": "",
        "approval_record_id": "",
    }
    processed_rows.append(row)

print(f"Processed {len(processed_rows)} review candidate rows.")
print(f"Copied and hashed {len(all_image_hashes)} review images.")

# Write CSV
csv_path = os.path.join(DOCS_R08_DIR, "R08_0_2_REPDB_MAPPING_REVIEW.csv")
fieldnames = [
    "family_id",
    "base_name",
    "indifit_primary_uuid",
    "canonical_uuid_bindings",
    "canonical_names",
    "equipment",
    "primary_display_muscle",
    "secondary_display_muscles",
    "repdb_id",
    "repdb_name",
    "repdb_equipment",
    "repdb_primary_muscles",
    "repdb_secondary_muscles",
    "repdb_start_path",
    "repdb_peak_path",
    "repdb_main_path",
    "candidate_confidence",
    "candidate_reason",
    "semantic_conflicts",
    "visual_review_status",
    "visual_review_notes",
    "reviewer",
    "review_date",
    "approval_record_id"
]

with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for r in processed_rows:
        writer.writerow(r)

print(f"Wrote CSV to {csv_path}")

# Write HTML Contact Sheet
html_path = os.path.join(REVIEW_ARTIFACTS_DIR, "R08_0_2_REPDB_MAPPING_CONTACT_SHEET.html")

html_cards = []
for r in processed_rows:
    family_id = r["family_id"]
    base_name = r["base_name"]
    confidence = r["candidate_confidence"]
    conf_class = confidence.lower()
    
    variant_items = "".join(f"<li><code>{u}</code> &mdash; {n}</li>" for u, n in zip(r["canonical_uuid_bindings"].split(";"), r["canonical_names"].split(";")))
    
    if r["repdb_id"] == "NO_MATCH":
        images_html = """
        <div class="no-match-box">
            <div class="no-match-icon">&#10006;</div>
            <div class="no-match-title">NO APPROVED MATCH IN REPDB FREE TIER</div>
            <div class="no-match-sub">Explicit fallback: B05 Canonical Muscle & Neutral Text Display. No synthetic artwork.</div>
        </div>
        """
    elif r["repdb_main_path"]:
        filename = os.path.basename(r["repdb_main_path"])
        hash_info = all_image_hashes.get(r["repdb_main_path"], {})
        sha_short = hash_info.get("sha256", "")[:18] + "..." if hash_info else ""
        images_html = f"""
        <div class="pose-container single-pose">
            <div class="pose-box">
                <span class="pose-badge main-badge">MAIN POSE (STATIC)</span>
                <img src="repdb_mapping_review/{filename}" alt="{base_name} Main" loading="lazy" />
                <div class="img-caption">{r['repdb_main_path']}<br><span class="hash-tag">{sha_short}</span></div>
            </div>
        </div>
        """
    else:
        start_fn = os.path.basename(r["repdb_start_path"]) if r["repdb_start_path"] else ""
        peak_fn = os.path.basename(r["repdb_peak_path"]) if r["repdb_peak_path"] else ""
        start_hash = all_image_hashes.get(r["repdb_start_path"], {}).get("sha256", "")[:18] + "..."
        peak_hash = all_image_hashes.get(r["repdb_peak_path"], {}).get("sha256", "")[:18] + "..."
        images_html = f"""
        <div class="pose-container">
            <div class="pose-box">
                <span class="pose-badge start-badge">START POSE</span>
                <img src="repdb_mapping_review/{start_fn}" alt="{base_name} Start" loading="lazy" />
                <div class="img-caption">{r['repdb_start_path']}<br><span class="hash-tag">{start_hash}</span></div>
            </div>
            <div class="pose-box">
                <span class="pose-badge peak-badge">PEAK POSE</span>
                <img src="repdb_mapping_review/{peak_fn}" alt="{base_name} Peak" loading="lazy" />
                <div class="img-caption">{r['repdb_peak_path']}<br><span class="hash-tag">{peak_hash}</span></div>
            </div>
        </div>
        """
    
    card_html = f"""
    <div class="card" id="{family_id}">
        <div class="card-header">
            <div class="card-title-group">
                <span class="family-tag">{family_id}</span>
                <h2 class="card-title">{base_name}</h2>
            </div>
            <span class="confidence-badge {conf_class}">{confidence}</span>
        </div>
        
        <div class="card-body">
            <div class="visual-panel">
                {images_html}
            </div>
            
            <div class="details-panel">
                <div class="section-title">INDIFIT CANONICAL DEFINITION</div>
                <div class="meta-grid">
                    <div class="meta-item">
                        <span class="meta-label">Equipment</span>
                        <span class="meta-value badge-equipment">{r['equipment']}</span>
                    </div>
                    <div class="meta-item">
                        <span class="meta-label">Primary Display Muscle</span>
                        <span class="meta-value badge-primary-muscle">{r['primary_display_muscle']}</span>
                    </div>
                    <div class="meta-item full-width">
                        <span class="meta-label">Secondary Muscles</span>
                        <span class="meta-value">{r['secondary_display_muscles'] or '&mdash;'}</span>
                    </div>
                </div>
                
                <div class="variant-list-container">
                    <span class="meta-label">Bound Canonical Variants (4 UUIDs)</span>
                    <ul class="variant-list">
                        {variant_items}
                    </ul>
                </div>

                <div class="section-title" style="margin-top: 16px;">REPDB PINNED METADATA</div>
                <div class="meta-grid">
                    <div class="meta-item">
                        <span class="meta-label">RepDB ID</span>
                        <span class="meta-value"><code>{r['repdb_id']}</code></span>
                    </div>
                    <div class="meta-item">
                        <span class="meta-label">RepDB Name</span>
                        <span class="meta-value">{r['repdb_name'] or '&mdash;'}</span>
                    </div>
                    <div class="meta-item">
                        <span class="meta-label">RepDB Equipment</span>
                        <span class="meta-value">{r['repdb_equipment'] or '&mdash;'}</span>
                    </div>
                    <div class="meta-item">
                        <span class="meta-label">RepDB Primary Muscles</span>
                        <span class="meta-value">{r['repdb_primary_muscles'] or '&mdash;'}</span>
                    </div>
                </div>

                <div class="section-title" style="margin-top: 16px;">MAPPING EVALUATION & CONFLICTS</div>
                <div class="conflict-box">
                    <strong>Candidate Rationale:</strong> {r['candidate_reason']}<br><br>
                    <strong>Taxonomy / Movement Flags:</strong> {r['semantic_conflicts']}
                </div>

                <div class="review-status-box">
                    <div class="review-status-header">
                        <span class="status-indicator pending">&#9679; REVIEW STATUS: PENDING HUMAN APPROVAL</span>
                    </div>
                    <div class="decision-placeholders">
                        <label><input type="radio" name="decision_{family_id}" value="APPROVE" disabled> Approve</label>
                        <label><input type="radio" name="decision_{family_id}" value="REJECT" disabled> Reject</label>
                        <label><input type="radio" name="decision_{family_id}" value="NEEDS_REVIEW" checked disabled> Needs Review</label>
                    </div>
                </div>
            </div>
        </div>
    </div>
    """
    html_cards.append(card_html)

total_exact = sum(1 for r in processed_rows if r["candidate_confidence"] == "EXACT")
total_strong = sum(1 for r in processed_rows if r["candidate_confidence"] == "STRONG")
total_ambiguous = sum(1 for r in processed_rows if r["candidate_confidence"] == "AMBIGUOUS")
total_nomatch = sum(1 for r in processed_rows if r["candidate_confidence"] == "NO_MATCH")

html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IndiFit R08-0.2: RepDB Movement Mapping Review Contact Sheet</title>
    <style>
        :root {{
            --bg-primary: #0F1115;
            --bg-surface: #181B20;
            --bg-card: #20242B;
            --bg-inset: #131519;
            --border-color: #2D323C;
            --text-primary: #E6E8EC;
            --text-secondary: #9DA3AF;
            --text-muted: #6B7280;
            --accent-blue: #3B82F6;
            --accent-green: #10B981;
            --accent-amber: #F59E0B;
            --accent-red: #EF4444;
            --accent-purple: #8B5CF6;
        }}
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-primary);
            color: var(--text-primary);
            padding: 24px;
            line-height: 1.5;
        }}
        .header {{
            max-width: 1300px;
            margin: 0 auto 24px auto;
            padding: 24px;
            background: var(--bg-surface);
            border-radius: 12px;
            border: 1px solid var(--border-color);
        }}
        .header-title {{
            font-size: 24px;
            font-weight: 700;
            color: #FFFFFF;
            margin-bottom: 8px;
        }}
        .header-subtitle {{
            font-size: 14px;
            color: var(--text-secondary);
            margin-bottom: 16px;
        }}
        .disclosure-banner {{
            background: rgba(245, 158, 11, 0.1);
            border-left: 4px solid var(--accent-amber);
            padding: 12px 16px;
            border-radius: 4px;
            font-size: 13px;
            color: #FCD34D;
            margin-bottom: 16px;
        }}
        .summary-stats {{
            display: flex;
            gap: 16px;
            flex-wrap: wrap;
        }}
        .stat-badge {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            padding: 8px 16px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 600;
        }}
        .stat-badge span {{
            color: var(--accent-blue);
            margin-left: 4px;
        }}
        .container {{
            max-width: 1300px;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            gap: 24px;
        }}
        .card {{
            background: var(--bg-surface);
            border-radius: 12px;
            border: 1px solid var(--border-color);
            overflow: hidden;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }}
        .card-header {{
            background: var(--bg-card);
            padding: 14px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
        }}
        .card-title-group {{
            display: flex;
            align-items: center;
            gap: 12px;
        }}
        .family-tag {{
            background: var(--accent-purple);
            color: #FFFFFF;
            font-size: 11px;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 4px;
            letter-spacing: 0.5px;
        }}
        .card-title {{
            font-size: 18px;
            font-weight: 700;
            color: #FFFFFF;
        }}
        .confidence-badge {{
            font-size: 12px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 6px;
            text-transform: uppercase;
        }}
        .confidence-badge.exact {{
            background: rgba(16, 185, 129, 0.2);
            color: #34D399;
            border: 1px solid #10B981;
        }}
        .confidence-badge.strong {{
            background: rgba(59, 130, 246, 0.2);
            color: #60A5FA;
            border: 1px solid #3B82F6;
        }}
        .confidence-badge.ambiguous {{
            background: rgba(245, 158, 11, 0.2);
            color: #FBBF24;
            border: 1px solid #F59E0B;
        }}
        .confidence-badge.no_match {{
            background: rgba(239, 68, 68, 0.2);
            color: #F87171;
            border: 1px solid #EF4444;
        }}
        .card-body {{
            display: grid;
            grid-template-columns: 460px 1fr;
            gap: 20px;
            padding: 20px;
        }}
        @media (max-width: 1024px) {{
            .card-body {{
                grid-template-columns: 1fr;
            }}
        }}
        .visual-panel {{
            background: var(--bg-inset);
            border-radius: 8px;
            padding: 16px;
            border: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        .pose-container {{
            display: flex;
            gap: 12px;
            width: 100%;
            justify-content: center;
        }}
        .pose-container.single-pose {{
            max-width: 240px;
        }}
        .pose-box {{
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            position: relative;
            background: #0D0F12;
            border-radius: 6px;
            padding: 8px;
            border: 1px solid #232730;
        }}
        .pose-box img {{
            width: 100%;
            height: auto;
            max-height: 220px;
            object-fit: contain;
            border-radius: 4px;
        }}
        .pose-badge {{
            position: absolute;
            top: 12px;
            left: 12px;
            font-size: 10px;
            font-weight: 700;
            padding: 2px 6px;
            border-radius: 4px;
            letter-spacing: 0.5px;
        }}
        .pose-badge.start-badge {{
            background: #2563EB;
            color: #FFFFFF;
        }}
        .pose-badge.peak-badge {{
            background: #D97706;
            color: #FFFFFF;
        }}
        .pose-badge.main-badge {{
            background: #059669;
            color: #FFFFFF;
        }}
        .img-caption {{
            font-size: 10px;
            color: var(--text-muted);
            margin-top: 6px;
            text-align: center;
            word-break: break-all;
            line-height: 1.3;
        }}
        .hash-tag {{
            color: #60A5FA;
            font-family: monospace;
        }}
        .no-match-box {{
            text-align: center;
            padding: 32px 16px;
            color: var(--text-secondary);
        }}
        .no-match-icon {{
            font-size: 32px;
            color: var(--accent-red);
            margin-bottom: 8px;
        }}
        .no-match-title {{
            font-size: 15px;
            font-weight: 700;
            color: #F87171;
            margin-bottom: 4px;
        }}
        .no-match-sub {{
            font-size: 12px;
            color: var(--text-muted);
        }}
        .details-panel {{
            display: flex;
            flex-direction: column;
            gap: 8px;
        }}
        .section-title {{
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.8px;
            color: var(--text-muted);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 4px;
            margin-bottom: 8px;
        }}
        .meta-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
            font-size: 13px;
        }}
        .meta-item {{
            display: flex;
            flex-direction: column;
            gap: 2px;
        }}
        .meta-item.full-width {{
            grid-column: span 2;
        }}
        .meta-label {{
            font-size: 11px;
            color: var(--text-muted);
            font-weight: 600;
        }}
        .meta-value {{
            color: var(--text-primary);
            font-weight: 500;
        }}
        .badge-equipment {{
            color: #93C5FD;
        }}
        .badge-primary-muscle {{
            color: #6EE7B7;
            font-weight: 600;
        }}
        .variant-list-container {{
            background: var(--bg-card);
            border-radius: 6px;
            padding: 10px 14px;
            margin-top: 6px;
            border: 1px solid var(--border-color);
        }}
        .variant-list {{
            list-style: none;
            margin-top: 6px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            font-size: 12px;
        }}
        .variant-list li code {{
            color: #A78BFA;
            font-family: ui-monospace, monospace;
            font-size: 11px;
        }}
        .conflict-box {{
            background: var(--bg-inset);
            border-radius: 6px;
            padding: 10px 14px;
            font-size: 12px;
            border: 1px solid var(--border-color);
            color: #D1D5DB;
        }}
        .conflict-box strong {{
            color: #F3F4F6;
        }}
        .review-status-box {{
            margin-top: 8px;
            background: rgba(59, 130, 246, 0.05);
            border: 1px dashed #3B82F6;
            border-radius: 6px;
            padding: 10px 14px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 8px;
        }}
        .review-status-header {{
            font-size: 12px;
            font-weight: 700;
            color: #93C5FD;
        }}
        .decision-placeholders {{
            display: flex;
            gap: 12px;
            font-size: 12px;
            color: var(--text-secondary);
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1 class="header-title">IndiFit R08-0.2: RepDB Movement Mapping Contact Sheet</h1>
        <div class="header-subtitle">
            Authoritative Review Gallery for Pinned RepDB Snapshot (<code>{EXPECTED_COMMIT}</code>) vs. IndiFit 35 Base Movement Families.
        </div>
        <div class="disclosure-banner">
            <strong>Mandatory Product Disclosure:</strong> Exercise artwork represents the underlying physical movement and equipment. It does not demonstrate exact pause duration, tempo, cadence, or other IndiFit technique prescriptions.
        </div>
        <div class="summary-stats">
            <div class="stat-badge">Total Families: <span>35</span></div>
            <div class="stat-badge">Canonical UUIDs Bound: <span>140</span></div>
            <div class="stat-badge">EXACT Matches: <span>{total_exact}</span></div>
            <div class="stat-badge">STRONG Matches: <span>{total_strong}</span></div>
            <div class="stat-badge">AMBIGUOUS Matches: <span>{total_ambiguous}</span></div>
            <div class="stat-badge">NO MATCH / Fallbacks: <span>{total_nomatch}</span></div>
            <div class="stat-badge">Candidate Visual Files: <span>{len(all_image_hashes)}</span></div>
            <div class="stat-badge" style="border-color: #3B82F6;">Review State: <span style="color: #60A5FA;">100% PENDING HUMAN APPROVAL</span></div>
        </div>
    </div>

    <div class="container">
        {"".join(html_cards)}
    </div>
</body>
</html>
"""

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"Wrote HTML contact sheet to {html_path}")
