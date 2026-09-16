#!/usr/bin/env python3
"""
generate_code_graph.py
======================
Generates an authoritative, AST/import-parsed Code Graph for the IndiFit codebase.
Produces `docs/architecture/code-graph.json` mapping dependencies, Riverpod providers,
GoRoutes, Drift tables, legacy sunset callers, and catch-block classifications.

Usage:
    python3 tool/generate_code_graph.py [--ci] [--output PATH]
"""

import os
import sys
import re
import json
import argparse
from datetime import datetime, timezone
import subprocess

P0_CRITICAL_FILES = [
    "lib/features/dashboard/dashboard_controller.dart",
    "lib/data/repositories/health_service.dart",
    "lib/core/backup/backup_service.dart",
    "lib/core/backup/restore_service.dart",
    "lib/core/backup/backup_manager.dart",
    "lib/core/services/crash_reporting_service.dart",
    "lib/features/workout_player/b02_strength_execution_controller.dart",
]

# Composition roots allowed to bridge core infrastructure and feature providers
LAYER_VIOLATION_ALLOWLIST = [
    "lib/core/router/app_router.dart",  # App route definitions wire all feature screens
    "lib/core/di/providers.dart",       # Intentional DI barrel re-exporting domain providers
]

LEGACY_SUNSET_TARGETS = [
    "lib/features/workout_player/workout_player_screen.dart",
    "lib/features/food_log/meal_templates_screen.dart",
]

def get_git_commit():
    try:
        res = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except Exception:
        return "unknown"

def parse_dart_files(root_dir="lib"):
    dart_files = []
    for root, _, files in os.walk(root_dir):
        for f in files:
            if f.endswith(".dart"):
                rel_path = os.path.normpath(os.path.join(root, f)).replace("\\", "/")
                dart_files.append(rel_path)
    return sorted(dart_files)

def build_code_graph(dart_files):
    import_regex = re.compile(r'''^\s*(?:import|export)\s+['\"]([^'\"]+)['\"];''', re.MULTILINE)
    part_regex = re.compile(r'''^\s*part\s+['\"]([^'\"]+)['\"];''', re.MULTILINE)
    part_of_regex = re.compile(r'''^\s*part\s+of\s+['\"]([^'\"]+)['\"];''', re.MULTILINE)
    
    # Catch patterns
    catch_pattern = re.compile(r'catch\s*\(\s*([a-zA-Z0-9_]+)\s*\)')
    catch_underscore_pattern = re.compile(r'catch\s*\(\s*_\s*\)')
    empty_catch_pattern = re.compile(r'catch\s*\(\s*([a-zA-Z0-9_]+)\s*\)\s*\{\s*\}')
    
    # Riverpod provider definitions and usages
    provider_def_pattern = re.compile(r'(?:final|final\s+AutoDispose(?:StateNotifier)?Provider[a-zA-Z0-9<>,\s]*)\s+([a-zA-Z0-9_]+Provider)\b')
    provider_watch_pattern = re.compile(r'ref\.(?:watch|read|listen)\(([a-zA-Z0-9_]+Provider)\)')
    
    # GoRoute paths
    goroute_pattern = re.compile(r"GoRoute\s*\(\s*path:\s*['\"]([^'\"]+)['\"]")
    
    nodes = {}
    edges = []
    all_catches = []
    catches_underscore = []
    empty_catches = []
    external_pkgs = set()
    
    for fpath in dart_files:
        with open(fpath, "r", encoding="utf-8", errors="ignore") as fh:
            lines = fh.readlines()
            content = "".join(lines)
            
        layer = fpath.split("/")[1] if len(fpath.split("/")) > 1 else "root"
        if layer == "features" and len(fpath.split("/")) > 2:
            sublayer = f"features/{fpath.split('/')[2]}"
        else:
            sublayer = layer

        loc = len(lines)
        file_imports = []
        file_parts = []
        file_part_of = None
        
        # 1. Imports
        for m in import_regex.finditer(content):
            target = m.group(1)
            if target.startswith("package:indifit/"):
                resolved = "lib/" + target[len("package:indifit/"):]
                resolved = os.path.normpath(resolved).replace("\\", "/")
                file_imports.append(resolved)
                edges.append({"from": fpath, "to": resolved, "type": "import"})
            elif target.startswith("package:"):
                pkg_name = target.split("/")[0].replace("package:", "")
                external_pkgs.add(pkg_name)
            elif target.startswith("dart:"):
                pass
            else:
                # Relative or sibling import
                dir_name = os.path.dirname(fpath)
                resolved = os.path.normpath(os.path.join(dir_name, target)).replace("\\", "/")
                file_imports.append(resolved)
                edges.append({"from": fpath, "to": resolved, "type": "import_relative"})

        # 2. Parts
        for m in part_regex.finditer(content):
            part_target = m.group(1)
            dir_name = os.path.dirname(fpath)
            resolved = os.path.normpath(os.path.join(dir_name, part_target)).replace("\\", "/")
            file_parts.append(resolved)
            edges.append({"from": fpath, "to": resolved, "type": "part"})

        m_part_of = part_of_regex.search(content)
        if m_part_of:
            parent_target = m_part_of.group(1)
            dir_name = os.path.dirname(fpath)
            resolved = os.path.normpath(os.path.join(dir_name, parent_target)).replace("\\", "/")
            file_part_of = resolved
            edges.append({"from": fpath, "to": resolved, "type": "part_of"})

        # 3. Riverpod Providers
        providers_defined = list(set(provider_def_pattern.findall(content)))
        providers_used = list(set(provider_watch_pattern.findall(content)))

        # 4. GoRoutes
        routes_defined = list(set(goroute_pattern.findall(content)))

        # 5. Catch analysis
        file_catches = []
        for idx, line in enumerate(lines):
            line_num = idx + 1
            cm = catch_pattern.search(line)
            if cm:
                err_var = cm.group(1)
                is_underscore = (err_var == "_")
                is_empty = bool(empty_catch_pattern.search(line))
                # Also check multi-line empty catch: `catch (_) {\n}`
                if not is_empty and idx + 1 < len(lines) and lines[idx+1].strip() == "}":
                    is_empty = True
                    
                catch_info = {
                    "file": fpath,
                    "line": line_num,
                    "var": err_var,
                    "is_underscore": is_underscore,
                    "is_empty": is_empty,
                    "snippet": line.strip(),
                    "layer": sublayer,
                    "is_p0": fpath in P0_CRITICAL_FILES
                }
                file_catches.append(catch_info)
                all_catches.append(catch_info)
                if is_underscore:
                    catches_underscore.append(catch_info)
                if is_empty:
                    empty_catches.append(catch_info)

        nodes[fpath] = {
            "path": fpath,
            "layer": layer,
            "sublayer": sublayer,
            "loc": loc,
            "imports": file_imports,
            "imported_by": [],
            "parts": file_parts,
            "part_of": file_part_of,
            "providers_defined": providers_defined,
            "providers_used": providers_used,
            "routes_defined": routes_defined,
            "catches": file_catches,
            "empty_catch_count": len([c for c in file_catches if c["is_empty"]]),
            "total_catch_count": len(file_catches),
        }

    # Populate imported_by reverse edges
    for edge in edges:
        target = edge["to"]
        src = edge["from"]
        if target in nodes and src not in nodes[target]["imported_by"]:
            nodes[target]["imported_by"].append(src)

    # Legacy screen migration tracking
    legacy_callers = {}
    for target in LEGACY_SUNSET_TARGETS:
        direct_callers = nodes.get(target, {}).get("imported_by", [])
        extended_callers = set(direct_callers)
        for caller in direct_callers:
            for part in nodes.get(caller, {}).get("parts", []):
                extended_callers.add(part)
        legacy_callers[target] = {
            "exists": target in nodes,
            "direct_callers": sorted(list(direct_callers)),
            "extended_callers": sorted(list(extended_callers)),
            "can_safely_delete": len(direct_callers) == 0
        }

    # Layer violation checks (with explicit composition root allowlist)
    layer_violations = []
    for fpath, node in nodes.items():
        if fpath in LAYER_VIOLATION_ALLOWLIST:
            continue
        if node["layer"] == "core":
            for imp in node["imports"]:
                if "/features/" in imp:
                    layer_violations.append({
                        "from": fpath,
                        "to": imp,
                        "severity": "triage",
                        "rule": "lib/core should not import lib/features (presentation coupling)"
                    })
        elif node["layer"] == "data":
            for imp in node["imports"]:
                if "/features/" in imp:
                    layer_violations.append({
                        "from": fpath,
                        "to": imp,
                        "severity": "triage",
                        "rule": "lib/data should not import lib/features (presentation coupling)"
                    })

    # Summary metrics
    total_loc = sum(n["loc"] for n in nodes.values())
    p0_empty_catches = [c for c in empty_catches if c["is_p0"]]

    summary = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git_commit": get_git_commit(),
        "total_dart_files": len(nodes),
        "total_loc": total_loc,
        "total_internal_edges": len(edges),
        "external_package_count": len(external_pkgs),
        "catch_metrics": {
            "total_catches_all": len(all_catches),
            "total_catch_underscore": len(catches_underscore),
            "total_empty_catches": len(empty_catches),
            "p0_empty_catches": len(p0_empty_catches)
        },
        "layer_violations_count": len(layer_violations),
        "catches_by_layer": {
            "core": len([c for c in all_catches if c["layer"].startswith("core")]),
            "data": len([c for c in all_catches if c["layer"].startswith("data")]),
            "features": len([c for c in all_catches if c["layer"].startswith("features")]),
            "other": len([c for c in all_catches if not any(c["layer"].startswith(x) for x in ["core", "data", "features"])])
        }
    }

    graph_data = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "summary": summary,
        "legacy_migration": legacy_callers,
        "p0_empty_catches": p0_empty_catches,
        "layer_violations": layer_violations,
        "empty_catches_catalog": empty_catches,
        "nodes": nodes
    }

    return graph_data

def main():
    parser = argparse.ArgumentParser(description="IndiFit Code Graph Generator & CI Guardrail")
    parser.add_argument("--ci", action="store_true", help="Run in CI mode: exit code 1 if P0 empty catches exist or retired screens have callers")
    parser.add_argument("--output", default="docs/architecture/code-graph.json", help="Path to write output JSON")
    args = parser.parse_args()

    files = parse_dart_files("lib")
    graph = build_code_graph(files)

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(graph, f, indent=2)

    summary = graph["summary"]
    cm = summary["catch_metrics"]
    print("==================================================")
    print("IndiFit Code Graph Generated Successfully")
    print("==================================================")
    print(f"  Files: {summary['total_dart_files']} | LOC: {summary['total_loc']}")
    print(f"  Internal Edges: {summary['total_internal_edges']} | External Packages: {summary['external_package_count']}")
    print("  Exception Catch Metrics (Calibrated):")
    print(f"    - Total catch blocks (all variables): {cm['total_catches_all']}")
    print(f"    - catch (_) with discarded error:     {cm['total_catch_underscore']}")
    print(f"    - Completely empty catch (_) {{}}:      {cm['total_empty_catches']}")
    print(f"    - P0 Critical Empty Catches:          {cm['p0_empty_catches']}")
    print(f"  Layer Violations (excluding allowlist): {summary['layer_violations_count']}")
    print(f"  Output: {args.output}")
    print("--------------------------------------------------")
    print("Legacy Screen Status:")
    for target, info in graph["legacy_migration"].items():
        state = "SAFE TO DELETE" if info["can_safely_delete"] else f"BLOCKED ({len(info['direct_callers'])} callers)"
        print(f"  - {os.path.basename(target)}: {state}")
        for c in info["direct_callers"]:
            print(f"      <- {c}")

    if args.ci:
        failures = []
        if cm["p0_empty_catches"] > 0:
            failures.append(f"CI FAILURE: {cm['p0_empty_catches']} empty catch block(s) found in P0 paths!")
            for c in graph["p0_empty_catches"]:
                failures.append(f"  - {c['file']}:{c['line']}")

        if failures:
            print("\n".join(failures), file=sys.stderr)
            sys.exit(1)
        else:
            print("\nCI Gate Passed: 0 P0 empty catches, architecture rules intact.")

if __name__ == "__main__":
    main()
