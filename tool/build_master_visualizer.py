#!/usr/bin/env python3
"""
build_master_visualizer.py
==========================
Generates a state-of-the-art, beautifully organized, colorful, and clean
Code & Knowledge Graph visualizer for IndiFit.

Directly addresses:
1. "I cant see which file is connected to which or what depends on what"
   - Directional curved arrows on dependencies.
   - Distinct emerald (#10b981) incoming caller arrows pointing IN.
   - Distinct rose (#f43f5e) outgoing import arrows pointing OUT.
   - Interactive 3-Column "Tree / X-Ray" mode isolating the exact dependency DAG for any file.
2. "make it more organised, clean, beautiful and colorful"
   - 9 rich, vibrant architectural subsystems (Electric Indigo, Hot Pink, Neon Purple, Dodger Blue, Cyan, Teal, Emerald, Amber, Sky Blue).
   - "Subsystem Islands" layout with spacious separation and glowing glass territory plates.
   - "Tier Flow" layout (Top-down DAG swimlanes: Screens -> Controllers -> Services -> Database).
   - "Concentric Radar" layout.
   - Permanent right sidebar with instant search dropdown, node info, and subsystem checklist.
"""

import json
import math
import os

with open('docs/architecture/code-graph.json', 'r', encoding='utf-8') as f:
    cg_data = json.load(f)

raw_nodes_dict = cg_data['nodes']

SUBSYSTEMS = {
    'workout': {
        'id': 'workout',
        'name': 'Workout & Execution',
        'color': '#6366f1',
        'icon': '🏋️',
        'cx': -470,
        'cy': -200,
        'tier_x': -380
    },
    'nutrition': {
        'id': 'nutrition',
        'name': 'Nutrition, Thali & Foods',
        'color': '#ec4899',
        'icon': '🍛',
        'cx': 470,
        'cy': -200,
        'tier_x': 380
    },
    'dashboard': {
        'id': 'dashboard',
        'name': 'Today & Dashboard',
        'color': '#8b5cf6',
        'icon': '📱',
        'cx': 0,
        'cy': -340,
        'tier_x': -250
    },
    'progress': {
        'id': 'progress',
        'name': 'Progress & Analytics',
        'color': '#3b82f6',
        'icon': '📈',
        'cx': 0,
        'cy': 0,
        'tier_x': 0
    },
    'settings': {
        'id': 'settings',
        'name': 'Settings & Privacy',
        'color': '#06b6d4',
        'icon': '⚙️',
        'cx': 550,
        'cy': 100,
        'tier_x': 130
    },
    'design_system': {
        'id': 'design_system',
        'name': 'Design System & UI',
        'color': '#14b8a6',
        'icon': '🎨',
        'cx': -550,
        'cy': 100,
        'tier_x': -510
    },
    'core_services': {
        'id': 'core_services',
        'name': 'Core Services & DI',
        'color': '#10b981',
        'icon': '⚡',
        'cx': -280,
        'cy': 370,
        'tier_x': 250
    },
    'database': {
        'id': 'database',
        'name': 'Drift SQLite & Data',
        'color': '#f59e0b',
        'icon': '💾',
        'cx': 280,
        'cy': 370,
        'tier_x': 510
    },
    'app': {
        'id': 'app',
        'name': 'App Root & Bootstrap',
        'color': '#38bdf8',
        'icon': '🚀',
        'cx': 0,
        'cy': -530,
        'tier_x': -120
    }
}

def classify_subsystem(path):
    lp = path.lower()
    if path.startswith('lib/app/') or path == 'lib/main.dart':
        return 'app'
    if 'workout' in lp or 'exercise' in lp or 'training' in lp or 'equipment' in lp:
        return 'workout'
    if 'nutrition' in lp or 'food' in lp or 'thali' in lp or 'meal' in lp or 'diet' in lp:
        return 'nutrition'
    if 'dashboard' in lp or 'today' in lp or 'calendar' in lp or 'activity' in lp:
        return 'dashboard'
    if 'progress' in lp or 'history' in lp or 'analytic' in lp or 'achievement' in lp or 'streak' in lp:
        return 'progress'
    if 'setting' in lp or 'profile' in lp or 'privacy' in lp or 'consent' in lp or 'erasure' in lp or 'onboarding' in lp:
        return 'settings'
    if 'b05_' in lp or 'theme' in lp or 'widgets/' in lp or 'presentation/' in lp or 'icons' in lp or 'colors' in lp:
        return 'design_system'
    if 'database' in lp or 'table' in lp or 'migration' in lp or 'seeder' in lp or 'repository' in lp or 'dao' in lp or path.startswith('lib/data/'):
        return 'database'
    return 'core_services'

def classify_tier(path):
    lp = path.lower()
    if any(s in lp for s in ['screen', 'page', 'sheet', 'card', 'dialog', 'modal', 'view', 'widgets', 'primitives']):
        return 0  # UI Screens
    elif any(s in lp for s in ['controller', 'notifier', 'provider', 'state', 'di/']):
        return 1  # Controllers & State
    elif any(s in lp for s in ['repository', 'dao', 'table', 'database', 'migration', 'seeder', 'schema']):
        return 3  # Database & Repositories
    else:
        return 2  # Domain Services & Engines

TIER_Y = {
    0: -340,  # UI Screens
    1: -110,  # Controllers
    2: 120,   # Services & Engines
    3: 350    # Database
}

# Create index mapping
path_to_idx = {p: i for i, p in enumerate(sorted(raw_nodes_dict.keys()))}

# Group nodes by subsystem for sunflower packing
sub_nodes = {k: [] for k in SUBSYSTEMS}
tier_nodes = {t: [] for t in range(4)}

for p, n in raw_nodes_dict.items():
    sub = classify_subsystem(p)
    tier = classify_tier(p)
    in_deg = len(n.get('imported_by', []))
    sub_nodes[sub].append((p, in_deg, tier))
    tier_nodes[tier].append(p)

# Sunflower packing within each island
GOLDEN_ANGLE = 137.5077640500378 * (math.pi / 180)
island_coords = {}

for sub, items in sub_nodes.items():
    # Sort by in_degree descending so important hubs are in center
    items.sort(key=lambda x: x[1], reverse=True)
    cfg = SUBSYSTEMS[sub]
    cx = cfg['cx']
    cy = cfg['cy']

    for i, (p, in_deg, tier) in enumerate(items):
        if i == 0:
            island_coords[p] = (cx, cy)
        else:
            r = 18.0 + math.sqrt(i) * 14.5
            theta = i * GOLDEN_ANGLE
            ix = cx + r * math.cos(theta)
            iy = cy + r * math.sin(theta)
            island_coords[p] = (round(ix, 1), round(iy, 1))

# Tier flow coordinates
tier_coords = {}
for tier, paths in tier_nodes.items():
    y = TIER_Y[tier]
    # Group by subsystem
    by_sub = {}
    for p in paths:
        s = classify_subsystem(p)
        by_sub.setdefault(s, []).append(p)
    
    for s, sub_paths in by_sub.items():
        base_x = SUBSYSTEMS[s]['tier_x']
        count = len(sub_paths)
        for j, p in enumerate(sub_paths):
            row = j // 4
            col = j % 4
            tx = base_x + (col - 1.5) * 18.0
            ty = y + (row - (count / 8)) * 18.0
            tier_coords[p] = (round(tx, 1), round(ty, 1))

# Radar coordinates (concentric rings by layer)
radar_coords = {}
layer_radii = {0: 160, 1: 240, 2: 320, 3: 400}
for tier, paths in tier_nodes.items():
    base_r = layer_radii[tier]
    n_count = len(paths)
    for k, p in enumerate(paths):
        angle = (2 * math.pi * k) / n_count
        rx = base_r * math.cos(angle)
        ry = base_r * math.sin(angle)
        radar_coords[p] = (round(rx, 1), round(ry, 1))

# Build final nodes list
final_nodes = []
key_pillars = {
    'app_database.dart',
    'b05_semantic_colors.dart',
    'b05_accessibility_primitives.dart',
    'circular_thali_plate.dart',
    'b02_strength_player_screen.dart',
    'dpdp_consent_dialog.dart',
    'providers.dart',
    'local_schedule_date_service.dart',
    'typed_quantities.dart',
    'nutrients.dart'
}

for p in sorted(raw_nodes_dict.keys()):
    n = raw_nodes_dict[p]
    idx = path_to_idx[p]
    basename = os.path.basename(p)
    sub = classify_subsystem(p)
    tier = classify_tier(p)
    
    in_links = [path_to_idx[imp] for imp in n.get('imported_by', []) if imp in path_to_idx]
    out_links = [path_to_idx[imp] for imp in n.get('imports', []) if imp in path_to_idx]
    
    is_anchor = len(in_links) >= 20 or basename in key_pillars
    
    ix, iy = island_coords[p]
    tx, ty = tier_coords[p]
    rx, ry = radar_coords[p]
    
    final_nodes.append({
        'i': idx,
        'p': p,
        'n': basename,
        'sub': sub,
        'tier': tier,
        'loc': n.get('loc', 0),
        'in': len(in_links),
        'out': len(out_links),
        'c': n.get('total_catch_count', 0),
        'ec': n.get('empty_catch_count', 0),
        'imports': out_links,
        'imported_by': in_links,
        'x_island': ix,
        'y_island': iy,
        'x_tier': tx,
        'y_tier': ty,
        'x_rad': rx,
        'y_rad': ry,
        'isAnchor': is_anchor
    })

# Build final edges list: [from_idx, to_idx] where from imports to (dependency: from -> to)
final_edges = []
for p, n in raw_nodes_dict.items():
    u = path_to_idx[p]
    for imp in n.get('imports', []):
        if imp in path_to_idx:
            v = path_to_idx[imp]
            final_edges.append([u, v])

print(f"Computed {len(final_nodes)} nodes and {len(final_edges)} edges across 9 subsystems!")

nodes_json = json.dumps(final_nodes, separators=(',', ':'))
edges_json = json.dumps(final_edges, separators=(',', ':'))
subsystems_json = json.dumps(SUBSYSTEMS, separators=(',', ':'))

html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>IndiFit — Architectural Knowledge & Dependency Graph</title>
  <script>
    window.onerror = function(msg, url, line, col, error) {{
      console.error("PAGE_ERROR:", msg, "at line", line, error);
      document.body.insertAdjacentHTML('afterbegin', '<div style="color:#ef4444;background:#1e1e2e;border:2px solid #f43f5e;z-index:99999;position:fixed;top:60px;left:20px;padding:12px 18px;border-radius:8px;font-size:14px;font-weight:700;box-shadow:0 10px 25px rgba(0,0,0,0.5);">RUNTIME ERROR: ' + msg + ' (line ' + line + ')</div>');
    }};
  </script>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: #080c14;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      height: 100vh;
      width: 100vw;
      overflow: hidden;
      display: flex;
    }}

    /* Main Stage */
    #main-stage {{
      flex: 1;
      height: 100vh;
      position: relative;
      overflow: hidden;
      background: radial-gradient(circle at 50% 45%, #0d1527 0%, #060911 100%);
    }}

    #graph-canvas {{
      width: 100%;
      height: 100%;
      display: block;
      cursor: grab;
    }}
    #graph-canvas:active {{ cursor: grabbing; }}

    /* Top Floating Glass Header */
    #top-bar {{
      position: absolute;
      top: 14px;
      left: 14px;
      right: 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: rgba(15, 23, 42, 0.86);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 12px;
      padding: 10px 16px;
      z-index: 10;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    }}

    .brand-section {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}
    .brand-badge {{
      width: 32px;
      height: 32px;
      background: linear-gradient(135deg, #38bdf8 0%, #6366f1 100%);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 15px;
      color: #fff;
      box-shadow: 0 2px 10px rgba(56, 189, 248, 0.35);
    }}
    .brand-title {{
      font-size: 14px;
      font-weight: 700;
      color: #f8fafc;
      letter-spacing: -0.01em;
      display: flex;
      align-items: center;
      gap: 8px;
    }}
    .status-tag {{
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #34d399;
      font-size: 10px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 9999px;
      letter-spacing: 0.05em;
    }}
    .brand-sub {{
      font-size: 11px;
      color: #94a3b8;
      font-family: monospace;
      margin-top: 1px;
    }}

    .top-controls {{
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    /* Layout Switcher */
    .view-group {{
      display: flex;
      background: rgba(8, 14, 28, 0.8);
      padding: 3px;
      border-radius: 8px;
      border: 1px solid rgba(255, 255, 255, 0.08);
    }}
    .view-btn {{
      background: transparent;
      border: none;
      color: #94a3b8;
      padding: 5px 11px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s;
    }}
    .view-btn.active {{
      background: #6366f1;
      color: #fff;
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.4);
    }}

    .tree-toggle-btn {{
      background: rgba(16, 185, 129, 0.15);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #34d399;
      padding: 5px 12px;
      border-radius: 7px;
      font-size: 11px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 5px;
      transition: all 0.15s;
    }}
    .tree-toggle-btn:hover, .tree-toggle-btn.active {{
      background: #10b981;
      color: #fff;
      box-shadow: 0 2px 10px rgba(16, 185, 129, 0.4);
    }}

    .reset-btn {{
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #cbd5e1;
      padding: 5px 11px;
      border-radius: 7px;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s;
    }}
    .reset-btn:hover {{
      background: rgba(255, 255, 255, 0.12);
      color: #fff;
    }}

    /* Active Legend Bar */
    #dependency-legend-hud {{
      position: absolute;
      top: 74px;
      left: 14px;
      display: flex;
      align-items: center;
      gap: 12px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 8px;
      padding: 6px 12px;
      font-size: 11px;
      font-weight: 600;
      z-index: 10;
      box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
    }}
    .legend-tag-pill {{
      display: flex;
      align-items: center;
      gap: 6px;
    }}
    .legend-indicator {{
      width: 8px;
      height: 8px;
      border-radius: 50%;
    }}

    /* Minimap Radar */
    #radar-hud {{
      position: absolute;
      bottom: 16px;
      left: 16px;
      background: rgba(15, 23, 42, 0.88);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 10px;
      padding: 10px;
      width: 162px;
      z-index: 10;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
    }}
    .radar-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 140px;
      font-size: 10px;
      font-weight: 700;
      color: #64748b;
      margin-bottom: 6px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }}
    #radar-canvas {{
      width: 140px;
      height: 90px;
      background: rgba(2, 6, 23, 0.6);
      border-radius: 6px;
      border: 1px solid rgba(255, 255, 255, 0.05);
      display: block;
    }}

    /* Right-hand Sidebar (Direct Reference from graph.html) */
    #sidebar {{
      width: 320px;
      background: #0f172a;
      border-left: 1px solid rgba(255, 255, 255, 0.08);
      display: flex;
      flex-direction: column;
      height: 100vh;
      flex-shrink: 0;
      z-index: 20;
      box-shadow: -10px 0 30px rgba(0, 0, 0, 0.4);
    }}

    /* Search Wrap */
    #search-wrap {{
      padding: 14px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      position: relative;
    }}
    #search-input-wrap {{
      position: relative;
      display: flex;
      align-items: center;
    }}
    #search {{
      width: 100%;
      background: #090d16;
      border: 1px solid #334155;
      color: #f1f5f9;
      padding: 8px 30px 8px 12px;
      border-radius: 7px;
      font-size: 12.5px;
      outline: none;
      transition: border-color 0.15s;
    }}
    #search:focus {{
      border-color: #6366f1;
      box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.25);
    }}
    #search-clear {{
      position: absolute;
      right: 10px;
      background: none;
      border: none;
      color: #64748b;
      cursor: pointer;
      font-size: 14px;
      display: none;
    }}

    #search-results {{
      position: absolute;
      top: 56px;
      left: 14px;
      right: 14px;
      max-height: 240px;
      overflow-y: auto;
      background: #090d16;
      border: 1px solid #334155;
      border-radius: 7px;
      z-index: 50;
      box-shadow: 0 12px 28px rgba(0, 0, 0, 0.6);
      display: none;
      padding: 4px;
    }}
    .search-item {{
      padding: 6px 10px;
      cursor: pointer;
      border-radius: 4px;
      font-size: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 2px;
      border-left: 3px solid #64748b;
      background: rgba(15, 23, 42, 0.4);
      transition: all 0.15s;
    }}
    .search-item:hover {{
      background: #1e293b;
      transform: translateX(2px);
    }}
    .search-item-title {{
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      color: #f1f5f9;
      font-weight: 500;
    }}
    .search-item-tag {{
      font-size: 10px;
      color: #94a3b8;
      margin-left: 6px;
      flex-shrink: 0;
    }}

    /* Node Info Panel */
    #info-panel {{
      padding: 14px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      max-height: 48vh;
      overflow-y: auto;
      flex: 0 0 auto;
    }}
    .section-title {{
      font-size: 11px;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      font-weight: 700;
      margin-bottom: 10px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    #info-content {{
      font-size: 12.5px;
      color: #cbd5e1;
      line-height: 1.5;
    }}
    #info-content .empty {{
      color: #64748b;
      font-style: italic;
      font-size: 12px;
      display: block;
      padding: 8px 0;
    }}

    .node-header-row {{
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
    }}
    .node-title {{
      font-size: 14px;
      font-weight: 700;
      color: #f8fafc;
      word-break: break-all;
    }}
    .layer-tag {{
      font-size: 10px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 9999px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }}

    .node-path {{
      font-size: 11px;
      color: #64748b;
      font-family: monospace;
      margin-bottom: 10px;
      word-break: break-all;
      background: rgba(0, 0, 0, 0.25);
      padding: 4px 6px;
      border-radius: 4px;
    }}

    .metric-grid {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 6px;
      margin-bottom: 10px;
    }}
    .metric-box {{
      background: rgba(15, 23, 42, 0.7);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 6px;
      padding: 6px 8px;
      text-align: center;
    }}
    .metric-val {{
      font-size: 13px;
      font-weight: 700;
      color: #f8fafc;
      font-family: monospace;
    }}
    .metric-lbl {{
      font-size: 9px;
      color: #64748b;
      text-transform: uppercase;
      margin-top: 2px;
    }}

    .action-row {{
      display: flex;
      gap: 6px;
      margin-bottom: 12px;
    }}
    .action-btn {{
      flex: 1;
      background: #6366f1;
      border: none;
      color: #fff;
      font-weight: 600;
      font-size: 11px;
      padding: 6px 8px;
      border-radius: 6px;
      cursor: pointer;
      transition: background 0.15s;
    }}
    .action-btn:hover {{ background: #4f46e5; }}
    .action-btn.secondary {{
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.1);
      color: #cbd5e1;
    }}
    .action-btn.secondary:hover {{ background: rgba(255, 255, 255, 0.14); color: #fff; }}

    /* Neighbor links */
    .neighbor-subhead {{
      font-size: 11px;
      font-weight: 700;
      margin: 8px 0 4px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    .neighbors-list {{
      max-height: 110px;
      overflow-y: auto;
      margin-bottom: 8px;
    }}
    .neighbor-link {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 4px 8px;
      margin: 2px 0;
      border-radius: 4px;
      cursor: pointer;
      font-size: 11.5px;
      background: rgba(15, 23, 42, 0.6);
      border-left: 3px solid #64748b;
      transition: all 0.15s;
    }}
    .neighbor-link:hover {{
      background: #1e293b;
      transform: translateX(2px);
    }}
    .neighbor-name {{
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      color: #e2e8f0;
    }}
    .neighbor-layer {{
      font-size: 9.5px;
      color: #64748b;
      margin-left: 4px;
      flex-shrink: 0;
    }}

    /* Subsystems Legend */
    #legend-wrap {{
      flex: 1;
      overflow-y: auto;
      padding: 14px;
    }}
    #legend-controls {{
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 10px;
      padding: 4px 0;
    }}
    #legend-controls label {{
      display: flex;
      align-items: center;
      gap: 7px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      color: #cbd5e1;
      user-select: none;
    }}
    #legend-controls label:hover {{ color: #fff; }}

    .legend-cb, #select-all-cb {{
      appearance: none;
      -webkit-appearance: none;
      width: 14px;
      height: 14px;
      border: 1.5px solid #475569;
      border-radius: 3px;
      background: #090d16;
      cursor: pointer;
      position: relative;
      flex-shrink: 0;
    }}
    .legend-cb:checked, #select-all-cb:checked {{
      background: #6366f1;
      border-color: #6366f1;
    }}
    .legend-cb:checked::after, #select-all-cb:checked::after {{
      content: '';
      position: absolute;
      left: 3.5px;
      top: 1px;
      width: 4px;
      height: 7px;
      border: solid #fff;
      border-width: 0 2px 2px 0;
      transform: rotate(45deg);
    }}
    #select-all-cb:indeterminate {{
      background: #6366f1;
      border-color: #6366f1;
    }}
    #select-all-cb:indeterminate::after {{
      content: '';
      position: absolute;
      left: 2.5px;
      top: 5px;
      width: 7px;
      height: 2px;
      background: #fff;
    }}

    .legend-item {{
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 5px 8px;
      cursor: pointer;
      border-radius: 6px;
      font-size: 12px;
      transition: background 0.15s;
      margin-bottom: 2px;
    }}
    .legend-item:hover {{ background: #1e293b; }}
    .legend-item.dimmed {{ opacity: 0.35; }}
    .legend-dot {{
      width: 10px;
      height: 10px;
      border-radius: 50%;
      flex-shrink: 0;
    }}
    .legend-label {{
      flex: 1;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      font-weight: 500;
    }}
    .legend-count {{
      color: #64748b;
      font-size: 11px;
      font-weight: 600;
      font-family: monospace;
    }}

    /* Footer Stats */
    #stats {{
      padding: 12px 14px;
      border-top: 1px solid rgba(255, 255, 255, 0.06);
      font-size: 11px;
      color: #64748b;
      background: #090d16;
      font-family: monospace;
      line-height: 1.4;
    }}
  </style>
</head>
<body>

  <!-- Left Canvas Area -->
  <div id="main-stage">
    <!-- Top Floating Toolbar -->
    <div id="top-bar">
      <div class="brand-section">
        <div class="brand-badge">IF</div>
        <div>
          <div class="brand-title">
            IndiFit Architecture & Knowledge Graph
            <span class="status-tag">SCHEMA V22 · CLEAN</span>
          </div>
          <div class="brand-sub">453 Dart Files · 277,731 LOC · 2,198 Dependencies · 0 P0 Catches</div>
        </div>
      </div>

      <div class="top-controls">
        <div class="view-group">
          <button id="layout-island" class="view-btn active">🏝️ Subsystems</button>
          <button id="layout-tier" class="view-btn">📊 Tier Flow</button>
          <button id="layout-rad" class="view-btn">🎯 Radar</button>
        </div>

        <button id="tree-toggle" class="tree-toggle-btn">
          <span>🌿 Tree View</span>
        </button>

        <button id="reset-btn" class="reset-btn">Reset</button>
      </div>
    </div>

    <!-- Active Dependency Legend HUD -->
    <div id="dependency-legend-hud">
      <div class="legend-tag-pill">
        <div class="legend-indicator" style="background:#10b981;box-shadow:0 0 8px #10b981;"></div>
        <span style="color:#10b981;">Incoming Callers (Who Depends On This)</span>
      </div>
      <div style="color:rgba(255,255,255,0.2);">|</div>
      <div class="legend-tag-pill">
        <div class="legend-indicator" style="background:#f43f5e;box-shadow:0 0 8px #f43f5e;"></div>
        <span style="color:#f43f5e;">Outgoing Imports (Dependencies Used)</span>
      </div>
    </div>

    <!-- Canvas -->
    <canvas id="graph-canvas"></canvas>

    <!-- Radar Minimap -->
    <div id="radar-hud">
      <div class="radar-header">
        <span>Network Radar</span>
        <span id="mini-count">453 Nodes</span>
      </div>
      <canvas id="radar-canvas" width="140" height="90"></canvas>
    </div>
  </div>

  <!-- Right Sidebar -->
  <div id="sidebar">
    <!-- Search Section -->
    <div id="search-wrap">
      <div id="search-input-wrap">
        <input id="search" type="text" placeholder="Search files (e.g. thali, db, workout)..." autocomplete="off">
        <button id="search-clear">×</button>
      </div>
      <div id="search-results"></div>
    </div>

    <!-- Node Info Panel -->
    <div id="info-panel">
      <div class="section-title">
        <span>Active Node Profile</span>
        <span id="info-catches" style="color:#10b981;font-size:10px;font-weight:600;">Clean AST</span>
      </div>
      <div id="info-content">
        <span class="empty">Click any node or search above to trace callers and dependencies.</span>
      </div>
    </div>

    <!-- Subsystems Legend -->
    <div id="legend-wrap">
      <div class="section-title">Architectural Subsystems (9)</div>
      <div id="legend-controls">
        <label>
          <input type="checkbox" id="select-all-cb" checked>
          <span>Select All</span>
        </label>
      </div>
      <div id="legend"></div>
    </div>

    <!-- Stats Footer -->
    <div id="stats">
      453 nodes &middot; 2,198 edges<br>
      9 subsystems &middot; 0 P0 catches
    </div>
  </div>

  <script>
    const rawNodes = {nodes_json};
    const rawEdges = {edges_json};
    const SUBSYSTEMS = {subsystems_json};
    const TIER_Y = {{ 0: -380, 1: -130, 2: 120, 3: 350 }};

    // Prepare node structures
    const nodes = rawNodes.map(n => {{
      const subCfg = SUBSYSTEMS[n.sub] || {{ color: '#94a3b8', name: 'Unknown' }};
      const radius = n.isAnchor ? Math.max(7.0, Math.min(18.0, 5.0 + Math.sqrt(n.in) * 1.3)) : Math.max(4.0, Math.min(14.0, 3.5 + mathSqrt(n.in) * 1.1));
      return {{
        ...n,
        x: n.x_island,
        y: n.y_island,
        targetX: n.x_island,
        targetY: n.y_island,
        radius,
        color: subCfg.color,
        subName: subCfg.name,
        icon: subCfg.icon
      }};
    }});

    function mathSqrt(val) {{
      return Math.sqrt(val || 0);
    }}

    // Lookup map
    const nodeMap = new Map();
    nodes.forEach(n => nodeMap.set(n.i, n));

    // Canvas setup
    const stage = document.getElementById('main-stage');
    const canvas = document.getElementById('graph-canvas');
    const ctx = canvas.getContext('2d');
    const miniCanvas = document.getElementById('radar-canvas');
    const miniCtx = miniCanvas.getContext('2d');

    let width = stage.clientWidth;
    let height = stage.clientHeight;
    canvas.width = width * window.devicePixelRatio;
    canvas.height = height * window.devicePixelRatio;
    ctx.scale(window.devicePixelRatio, window.devicePixelRatio);

    window.addEventListener('resize', () => {{
      width = stage.clientWidth;
      height = stage.clientHeight;
      canvas.width = width * window.devicePixelRatio;
      canvas.height = height * window.devicePixelRatio;
      ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
    }});

    // Camera state
    let cameraX = width / 2;
    let cameraY = height / 2 + 35;
    let zoom = Math.min(width, height) / 1480;
    let targetCameraX = cameraX;
    let targetCameraY = cameraY;
    let targetZoom = zoom;

    function screenToWorld(sx, sy) {{
      return {{
        x: (sx - cameraX) / zoom,
        y: (sy - cameraY) / zoom
      }};
    }}

    function worldToScreen(wx, wy) {{
      return {{
        x: wx * zoom + cameraX,
        y: wy * zoom + cameraY
      }};
    }}

    // State
    let selectedNode = null;
    let hoveredNode = null;
    let currentLayout = 'island';
    let isTreeMode = false;
    let searchQuery = '';
    const hiddenSubsystems = new Set();

    // Convex Hull Algorithm (Andrew's Monotone Chain from graph.html)
    function convexHull(pts) {{
      const p = pts.slice().sort((a, b) => (a.x - b.x) || (a.y - b.y));
      if (p.length < 3) return p;
      const cross = (o, a, b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
      const build = seq => {{
        const out = [];
        for (const q of seq) {{
          while (out.length >= 2 && cross(out[out.length - 2], out[out.length - 1], q) <= 0) out.pop();
          out.push(q);
        }}
        out.pop();
        return out;
      }};
      const hull = build(p).concat(build(p.slice().reverse()));
      return hull.length >= 3 ? hull : p;
    }}

    // Directional Curved Arrow Drawing
    function drawCurvedArrow(ctx, sx, sy, tx, ty, color, width, headSize, curveOffset) {{
      const mx = (sx + tx) / 2;
      const my = (sy + ty) / 2;
      const dx = tx - sx;
      const dy = ty - sy;
      const cx = mx - dy * curveOffset;
      const cy = my + dx * curveOffset;

      const angle = Math.atan2(ty - cy, tx - cx);
      const endX = tx - Math.cos(angle) * (headSize * 0.7);
      const endY = ty - Math.sin(angle) * (headSize * 0.7);

      ctx.save();
      ctx.strokeStyle = color;
      ctx.fillStyle = color;
      ctx.lineWidth = width;

      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.quadraticCurveTo(cx, cy, endX, endY);
      ctx.stroke();

      // Arrow head
      ctx.beginPath();
      ctx.moveTo(tx, ty);
      ctx.lineTo(tx - headSize * Math.cos(angle - Math.PI / 6), ty - headSize * Math.sin(angle - Math.PI / 6));
      ctx.lineTo(tx - headSize * Math.cos(angle + Math.PI / 6), ty - headSize * Math.sin(angle + Math.PI / 6));
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }}

    // Apply Layout Positions
    function applyLayout(mode) {{
      currentLayout = mode;
      isTreeMode = false;
      document.getElementById('tree-toggle').classList.remove('active');

      if (mode === 'island') {{
        targetZoom = Math.min(width, height) / 1480;
        targetCameraX = width / 2;
        targetCameraY = height / 2 + 35;
        nodes.forEach(n => {{ n.targetX = n.x_island; n.targetY = n.y_island; }});
      }} else if (mode === 'tier') {{
        targetZoom = Math.min(width, height) / 1400;
        targetCameraX = width / 2;
        targetCameraY = height / 2 + 20;
        nodes.forEach(n => {{ n.targetX = n.x_tier; n.targetY = n.y_tier; }});
      }} else if (mode === 'rad') {{
        targetZoom = Math.min(width, height) / 1450;
        targetCameraX = width / 2;
        targetCameraY = height / 2 + 25;
        nodes.forEach(n => {{ n.targetX = n.x_rad; n.targetY = n.y_rad; }});
      }}
    }}

    // Apply Tree / X-Ray Layout for Selected Node
    function applyTreeLayout(rootNode) {{
      if (!rootNode) return;
      isTreeMode = true;
      document.getElementById('tree-toggle').classList.add('active');

      const callers = rootNode.imported_by.map(i => nodeMap.get(i)).filter(Boolean);
      const callees = rootNode.imports.map(i => nodeMap.get(i)).filter(Boolean);

      callers.sort((a, b) => (a.sub.localeCompare(b.sub)) || (b.in - a.in));
      callees.sort((a, b) => (a.sub.localeCompare(b.sub)) || (b.in - a.in));

      rootNode.targetX = 0;
      rootNode.targetY = 0;

      // Arrange callers on left columns
      const callersPerCol = 24;
      const callerCols = Math.ceil(callers.length / callersPerCol) || 1;
      const cStep = Math.max(34, Math.min(52, 480 / Math.max(1, Math.min(callers.length, callersPerCol))));
      callers.forEach((c, idx) => {{
        const col = Math.floor(idx / callersPerCol);
        const row = idx % callersPerCol;
        const totalInThisCol = Math.min(callersPerCol, callers.length - col * callersPerCol);
        c.targetX = -260 - col * 190;
        c.targetY = (row - (totalInThisCol - 1) / 2) * cStep;
      }});

      // Arrange callees on right columns
      const calleesPerCol = 24;
      const calleeCols = Math.ceil(callees.length / calleesPerCol) || 1;
      const dStep = Math.max(34, Math.min(52, 480 / Math.max(1, Math.min(callees.length, calleesPerCol))));
      callees.forEach((d, idx) => {{
        const col = Math.floor(idx / calleesPerCol);
        const row = idx % calleesPerCol;
        const totalInThisCol = Math.min(calleesPerCol, callees.length - col * calleesPerCol);
        d.targetX = 260 + col * 190;
        d.targetY = (row - (totalInThisCol - 1) / 2) * dStep;
      }});

      // Push all other nodes away into a faint peripheral orbit
      nodes.forEach(n => {{
        if (n.i !== rootNode.i && !rootNode.imported_by.includes(n.i) && !rootNode.imports.includes(n.i)) {{
          const ang = (n.i / nodes.length) * 2 * Math.PI;
          n.targetX = 1400 * Math.cos(ang);
          n.targetY = 1400 * Math.sin(ang);
        }}
      }});

      // Calculate true bounding box of active tree to perfectly center camera
      const minX = callers.length > 0 ? (-260 - (callerCols - 1) * 190 - 90) : -120;
      const maxX = callees.length > 0 ? (260 + (calleeCols - 1) * 190 + 90) : 120;
      const centerX = (minX + maxX) / 2;
      const spanX = maxX - minX;
      const maxRows = Math.min(24, Math.max(callers.length, callees.length, 1));
      const spanY = maxRows * 30 + 100;

      targetZoom = Math.max(0.42, Math.min(1.1, Math.min((width - 80) / spanX, (height - 90) / spanY)));
      targetCameraX = width / 2 - centerX * targetZoom;
      targetCameraY = height / 2;
    }}

    // Main Render Loop
    let pulse = 0;
    function animate() {{
      pulse += 0.035;

      cameraX += (targetCameraX - cameraX) * 0.12;
      cameraY += (targetCameraY - cameraY) * 0.12;
      zoom += (targetZoom - zoom) * 0.12;

      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        n.x += (n.targetX - n.x) * 0.15;
        n.y += (n.targetY - n.y) * 0.15;
      }}

      draw();
      requestAnimationFrame(animate);
    }}

    function draw() {{
      ctx.clearRect(0, 0, width, height);

      // Background Grid
      const gridSize = 60 * zoom;
      if (gridSize > 18) {{
        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.022)';
        ctx.lineWidth = 1;
        const startX = cameraX % gridSize;
        const startY = cameraY % gridSize;
        ctx.beginPath();
        for (let x = startX; x < width; x += gridSize) {{
          ctx.moveTo(x, 0); ctx.lineTo(x, height);
        }}
        for (let y = startY; y < height; y += gridSize) {{
          ctx.moveTo(0, y); ctx.lineTo(width, y);
        }}
        ctx.stroke();
        ctx.restore();
      }}

      // PASS 0: Shaded Subsystem Island Plates (When in Islands Mode)
      if (currentLayout === 'island' && !isTreeMode) {{
        for (const [subKey, cfg] of Object.entries(SUBSYSTEMS)) {{
          if (hiddenSubsystems.has(subKey)) continue;
          const islandMembers = nodes.filter(n => n.sub === subKey);
          if (islandMembers.length < 3) continue;

          const pts = islandMembers.map(n => worldToScreen(n.x, n.y));
          const cx = pts.reduce((s, p) => s + p.x, 0) / pts.length;
          const cy = pts.reduce((s, p) => s + p.y, 0) / pts.length;
          const hull = convexHull(pts);
          if (hull.length < 3) continue;

          const expanded = hull.map(p => ({{
            x: cx + (p.x - cx) * 1.15,
            y: cy + (p.y - cy) * 1.15
          }}));

          ctx.save();
          ctx.beginPath();
          ctx.moveTo(expanded[0].x, expanded[0].y);
          for (let j = 1; j < expanded.length; j++) {{
            ctx.lineTo(expanded[j].x, expanded[j].y);
          }}
          ctx.closePath();
          ctx.fillStyle = `${{cfg.color}}0f`; // 6% alpha
          ctx.fill();
          ctx.strokeStyle = `${{cfg.color}}44`; // 27% alpha
          ctx.lineWidth = 1.2;
          ctx.setLineDash([5, 5]);
          ctx.stroke();

          // Floating Territory Badge with Glassmorphism Pill
          if (zoom > 0.35 && zoom < 2.0) {{
            ctx.save();
            ctx.font = '700 12px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
            const badgeText = `${{cfg.icon}} ${{cfg.name.toUpperCase()}} (${{islandMembers.length}})`;
            const btw = ctx.measureText(badgeText).width;
            const bx = cx - (btw + 20) / 2;
            const by = cy - 26;
            ctx.fillStyle = 'rgba(15, 23, 42, 0.88)';
            ctx.strokeStyle = `${{cfg.color}}55`;
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.roundRect(bx, by, btw + 20, 22, 11);
            ctx.fill();
            ctx.stroke();

            ctx.fillStyle = cfg.color;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(badgeText, cx, by + 11);
            ctx.restore();
          }}
          ctx.restore();
        }}
      }}

      // PASS 0.5: Swimlane Banners (When in Tier Flow Mode)
      if (currentLayout === 'tier' && !isTreeMode) {{
        ctx.save();
        const tierLabels = [
          {{ name: 'TIER 1: UI SCREENS & PRESENTATION', y: TIER_Y[0] }},
          {{ name: 'TIER 2: CONTROLLERS & RIVERPOD NOTIFIERS', y: TIER_Y[1] }},
          {{ name: 'TIER 3: CORE DOMAIN SERVICES & ALGORITHMS', y: TIER_Y[2] }},
          {{ name: 'TIER 4: REPOSITORIES & DRIFT SQLITE V22', y: TIER_Y[3] }}
        ];
        tierLabels.forEach(tl => {{
          const sy = tl.y * zoom + cameraY;
          ctx.fillStyle = 'rgba(255, 255, 255, 0.025)';
          ctx.fillRect(0, sy - 80 * zoom, width, 160 * zoom);
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.06)';
          ctx.lineWidth = 1;
          ctx.setLineDash([6, 6]);
          ctx.beginPath();
          ctx.moveTo(0, sy - 80 * zoom); ctx.lineTo(width, sy - 80 * zoom);
          ctx.stroke();

          ctx.font = '700 11px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
          ctx.fillStyle = '#64748b';
          ctx.textAlign = 'left';
          ctx.fillText(tl.name, 24, sy - 60 * zoom);
        }});
        ctx.restore();
      }}

      // PASS 1: Edges with Directionality
      const activeNode = selectedNode || hoveredNode;

      for (let i = 0; i < rawEdges.length; i++) {{
        const [uId, vId] = rawEdges[i]; // u imports v (Dependency flows: u -> v)
        const uNode = nodeMap.get(uId);
        const vNode = nodeMap.get(vId);
        if (!uNode || !vNode) continue;
        if (hiddenSubsystems.has(uNode.sub) || hiddenSubsystems.has(vNode.sub)) continue;

        const uPos = worldToScreen(uNode.x, uNode.y);
        const vPos = worldToScreen(vNode.x, vNode.y);

        // Check if active in selected node's neighborhood
        const isIncoming = activeNode && vNode.i === activeNode.i;  // u imports activeNode (u is CALLER of activeNode)
        const isOutgoing = activeNode && uNode.i === activeNode.i;  // activeNode imports vNode (v is DEPENDENCY of activeNode)

        if (activeNode) {{
          if (isIncoming) {{
            // INCOMING CALLER: Emerald line & arrow pointing INTO activeNode
            drawCurvedArrow(ctx, uPos.x, uPos.y, vPos.x, vPos.y, '#10b981', 2.4, 7.5, 0.08);
          }} else if (isOutgoing) {{
            // OUTGOING DEPENDENCY: Rose line & arrow pointing OUT to dependency
            drawCurvedArrow(ctx, uPos.x, uPos.y, vPos.x, vPos.y, '#f43f5e', 2.4, 7.5, 0.08);
          }}
          // If not connected to activeNode, skip edge completely for pristine clarity!
        }} else {{
          // Default Idle View: Draw subtle colored edges
          ctx.save();
          const sameSub = uNode.sub === vNode.sub;
          if (sameSub) {{
            ctx.strokeStyle = `${{uNode.color}}22`;
            ctx.lineWidth = 0.7;
          }} else {{
            ctx.strokeStyle = 'rgba(255, 255, 255, 0.04)';
            ctx.lineWidth = 0.5;
          }}
          ctx.beginPath();
          ctx.moveTo(uPos.x, uPos.y);
          const mx = (uPos.x + vPos.x) / 2;
          const my = (uPos.y + vPos.y) / 2;
          const dx = vPos.x - uPos.x;
          const dy = vPos.y - uPos.y;
          ctx.quadraticCurveTo(mx - dy * 0.08, my + dx * 0.08, vPos.x, vPos.y);
          ctx.stroke();
          ctx.restore();
        }}
      }}

      // PASS 2: Nodes
      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        if (hiddenSubsystems.has(n.sub)) continue;

        const pos = worldToScreen(n.x, n.y);
        const isSelected = selectedNode && selectedNode.i === n.i;
        const isHovered = hoveredNode && hoveredNode.i === n.i;
        
        const isIncomingCaller = activeNode && activeNode.imported_by.includes(n.i);
        const isOutgoingDep = activeNode && activeNode.imports.includes(n.i);

        let alpha = 1.0;
        if (searchQuery) {{
          alpha = (n.n.toLowerCase().includes(searchQuery) || n.p.toLowerCase().includes(searchQuery)) ? 1.0 : 0.12;
        }} else if (activeNode && !isSelected && !isHovered && !isIncomingCaller && !isOutgoingDep) {{
          alpha = 0.12;
        }}

        ctx.save();
        ctx.globalAlpha = alpha;

        const r = isTreeMode ? 5.5 : Math.max(3.5, n.radius * zoom);

        // Glowing Orbit Rings for active or anchor nodes (suppressed in Tree Mode)
        if (isSelected && !isTreeMode) {{
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, r + 7, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(99, 102, 241, 0.35)';
          ctx.fill();
        }} else if (isIncomingCaller && !isTreeMode) {{
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, r + 5, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(16, 185, 129, 0.3)';
          ctx.fill();
        }} else if (isOutgoingDep && !isTreeMode) {{
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, r + 5, 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(244, 63, 94, 0.3)';
          ctx.fill();
        }} else if (n.isAnchor && !activeNode && !isTreeMode) {{
          ctx.save();
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, r + 4 + Math.sin(pulse + n.i) * 1.2, 0, Math.PI * 2);
          ctx.strokeStyle = n.color;
          ctx.lineWidth = 1;
          ctx.setLineDash([3, 3]);
          ctx.globalAlpha = 0.45;
          ctx.stroke();
          ctx.restore();
        }}

        // Solid Node Core
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, r, 0, Math.PI * 2);
        if (isIncomingCaller) ctx.fillStyle = '#10b981';
        else if (isOutgoingDep) ctx.fillStyle = '#f43f5e';
        else ctx.fillStyle = n.color;
        ctx.fill();

        // Crisp Border
        ctx.lineWidth = isSelected ? 2.5 : 1.2;
        ctx.strokeStyle = isSelected ? '#ffffff' : (isIncomingCaller ? '#10b981' : (isOutgoingDep ? '#f43f5e' : 'rgba(255, 255, 255, 0.45)'));
        ctx.stroke();

        ctx.restore();
      }}

      // PASS 3: Dynamic Non-Overlapping Landmark Labels
      const placedBoxes = [];
      function collidesWithPlaced(box) {{
        for (let j = 0; j < placedBoxes.length; j++) {{
          const b = placedBoxes[j];
          if (box.x < b.x + b.w && box.x + box.w > b.x &&
              box.y < b.y + b.h && box.y + box.h > b.y) {{
            return true;
          }}
        }}
        return false;
      }}

      const candidates = [];
      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        if (hiddenSubsystems.has(n.sub)) continue;

        const isSelected = selectedNode && selectedNode.i === n.i;
        const isHovered = hoveredNode && hoveredNode.i === n.i;
        const isCaller = activeNode && activeNode.imported_by.includes(n.i);
        const isDep = activeNode && activeNode.imports.includes(n.i);
        const isAnchor = n.isAnchor;

        if (isSelected || isHovered || isCaller || isDep || isAnchor || isTreeMode || zoom > 1.25) {{
          let priority = n.in || 0;
          if (isSelected) priority += 100000;
          else if (isHovered) priority += 50000;
          else if (isCaller || isDep) priority += 20000;
          else if (isAnchor) priority += 1000;
          candidates.push({{ n, isSelected, isHovered, isCaller, isDep, isAnchor, priority }});
        }}
      }}
      candidates.sort((a, b) => b.priority - a.priority);

      for (let i = 0; i < candidates.length; i++) {{
        const {{ n, isSelected, isHovered, isCaller, isDep, isAnchor }} = candidates[i];
        const pos = worldToScreen(n.x, n.y);
        const r = Math.max(3.5, n.radius * zoom);
        const fs = Math.max(10, Math.min(12, Math.round(11 * Math.sqrt(zoom))));
        ctx.font = `600 ${{fs}}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
        const text = n.n;
        const tw = ctx.measureText(text).width;
        const boxW = tw + 24;
        const boxH = fs + 8;
        let box;
        if (isTreeMode) {{
          box = {{
            x: pos.x - boxW / 2,
            y: pos.y - boxH / 2,
            w: boxW,
            h: boxH
          }};
        }} else {{
          box = {{
            x: pos.x - boxW / 2,
            y: pos.y + r + 5,
            w: boxW,
            h: boxH
          }};
        }}

        if (!isSelected && !isHovered) {{
          if (collidesWithPlaced({{ x: box.x - 3, y: box.y - 2, w: box.w + 6, h: box.h + 4 }})) {{
            continue;
          }}
        }}
        placedBoxes.push(box);

        ctx.save();
        let alpha = 1.0;
        if (searchQuery) {{
          alpha = (n.n.toLowerCase().includes(searchQuery) || n.p.toLowerCase().includes(searchQuery)) ? 1.0 : 0.12;
        }} else if (activeNode && !isSelected && !isHovered && !isCaller && !isDep) {{
          alpha = 0.12;
        }}
        ctx.globalAlpha = alpha;

        // Pill container
        ctx.fillStyle = 'rgba(8, 14, 28, 0.94)';
        let strokeCol = 'rgba(255, 255, 255, 0.22)';
        if (isSelected) strokeCol = '#ffffff';
        else if (isCaller) strokeCol = '#10b981';
        else if (isDep) strokeCol = '#f43f5e';
        else if (isAnchor) strokeCol = n.color;

        ctx.strokeStyle = strokeCol;
        ctx.lineWidth = (isSelected || isCaller || isDep) ? 1.8 : 1.0;
        ctx.beginPath();
        ctx.roundRect(box.x, box.y, box.w, box.h, 5);
        ctx.fill();
        ctx.stroke();

        // Indicator dot
        ctx.beginPath();
        ctx.arc(box.x + 8, box.y + box.h / 2, 2.5, 0, Math.PI * 2);
        ctx.fillStyle = isCaller ? '#10b981' : (isDep ? '#f43f5e' : n.color);
        ctx.fill();

        // Label text
        ctx.fillStyle = isSelected ? '#ffffff' : (isHovered ? '#38bdf8' : (isCaller ? '#34d399' : (isDep ? '#fb7185' : '#e2e8f0')));
        ctx.textAlign = 'left';
        ctx.fillText(text, box.x + 15, box.y + fs - 1);
        ctx.restore();
      }}

      // PASS 4: Minimap Radar
      miniCtx.clearRect(0, 0, 140, 90);
      const minBounds = {{ x1: -750, y1: -600, x2: 750, y2: 500 }};
      const sx = 140 / (minBounds.x2 - minBounds.x1);
      const sy = 90 / (minBounds.y2 - minBounds.y1);

      let visibleCount = 0;
      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        if (hiddenSubsystems.has(n.sub)) continue;
        if (isTreeMode && selectedNode && n.i !== selectedNode.i && !selectedNode.imported_by.includes(n.i) && !selectedNode.imports.includes(n.i)) continue;
        visibleCount++;
        const mx = (n.x - minBounds.x1) * sx;
        const my = (n.y - minBounds.y1) * sy;
        miniCtx.fillStyle = n.color;
        miniCtx.fillRect(mx, my, 1.5, 1.5);
      }}
      document.getElementById('mini-count').textContent = `${{visibleCount}} Nodes`;

      // Camera viewport in minimap
      const vTopLeft = screenToWorld(0, 0);
      const vBottomRight = screenToWorld(width, height);
      const rx = (vTopLeft.x - minBounds.x1) * sx;
      const ry = (vTopLeft.y - minBounds.y1) * sy;
      const rw = (vBottomRight.x - vTopLeft.x) * sx;
      const rh = (vBottomRight.y - vTopLeft.y) * sy;

      miniCtx.strokeStyle = 'rgba(99, 102, 241, 0.65)';
      miniCtx.lineWidth = 1;
      miniCtx.strokeRect(rx, ry, rw, rh);
    }}

    // Node Selection & Inspection
    function selectNode(n) {{
      selectedNode = n;
      showInfo(n);
    }}

    function focusNode(nodeId) {{
      const n = nodeMap.get(nodeId);
      if (!n) return;
      targetZoom = 2.2;
      targetCameraX = width / 2 - n.x * targetZoom;
      targetCameraY = height / 2 - n.y * targetZoom;
      selectNode(n);
    }}

    function showInfo(n) {{
      const subCfg = SUBSYSTEMS[n.sub] || {{ name: 'Unknown', color: '#94a3b8' }};
      
      const callerLinks = n.imported_by.map(idx => {{
        const caller = nodeMap.get(idx);
        if (!caller) return '';
        return `<div class="neighbor-link" style="border-left-color:#10b981;" onclick="focusNode(${{caller.i}})">
          <span class="neighbor-name" style="color:#34d399;">← ${{caller.n}}</span>
          <span class="neighbor-layer">${{caller.sub}}</span>
        </div>`;
      }}).join('');

      const calleeLinks = n.imports.map(idx => {{
        const callee = nodeMap.get(idx);
        if (!callee) return '';
        return `<div class="neighbor-link" style="border-left-color:#f43f5e;" onclick="focusNode(${{callee.i}})">
          <span class="neighbor-name" style="color:#fb7185;">→ ${{callee.n}}</span>
          <span class="neighbor-layer">${{callee.sub}}</span>
        </div>`;
      }}).join('');

      document.getElementById('info-catches').textContent = n.ec > 0 ? `${{n.ec}} Empty Catches` : 'Clean AST';
      document.getElementById('info-catches').style.color = n.ec > 0 ? '#ef4444' : '#10b981';

      document.getElementById('info-content').innerHTML = `
        <div class="node-header-row">
          <span class="node-title">${{n.n}}</span>
          <span class="layer-tag" style="background:${{subCfg.color}}22;color:${{subCfg.color}};border:1px solid ${{subCfg.color}}44;">${{subCfg.name}}</span>
        </div>
        <div class="node-path">${{n.p}}</div>

        <div class="metric-grid">
          <div class="metric-box">
            <div class="metric-val">${{n.loc.toLocaleString()}}</div>
            <div class="metric-lbl">Lines</div>
          </div>
          <div class="metric-box">
            <div class="metric-val" style="color:#10b981;">${{n.in}}</div>
            <div class="metric-lbl">Callers</div>
          </div>
          <div class="metric-box">
            <div class="metric-val" style="color:#f43f5e;">${{n.out}}</div>
            <div class="metric-lbl">Imports</div>
          </div>
        </div>

        <div class="action-row">
          <button class="action-btn" onclick="focusNode(${{n.i}})">Center Camera</button>
          <button class="action-btn secondary" onclick="applyTreeLayout(nodeMap.get(${{n.i}}))">🌿 Isolate Tree</button>
        </div>

        <div class="neighbor-subhead" style="color:#10b981;">
          <span>Incoming Callers (Who Depends On This)</span>
          <span style="font-family:monospace;">${{n.in}}</span>
        </div>
        <div class="neighbors-list">
          ${{callerLinks || '<div style="color:#64748b;font-style:italic;padding:4px 0;">No callers (entry/leaf)</div>'}}
        </div>

        <div class="neighbor-subhead" style="color:#f43f5e;">
          <span>Outgoing Imports (Dependencies Used)</span>
          <span style="font-family:monospace;">${{n.out}}</span>
        </div>
        <div class="neighbors-list">
          ${{calleeLinks || '<div style="color:#64748b;font-style:italic;padding:4px 0;">No internal imports</div>'}}
        </div>
      `;
    }}

    // Search Autocomplete
    const searchInput = document.getElementById('search');
    const searchResults = document.getElementById('search-results');
    const searchClear = document.getElementById('search-clear');

    searchInput.addEventListener('input', () => {{
      searchQuery = searchInput.value.toLowerCase().trim();
      searchClear.style.display = searchQuery ? 'block' : 'none';
      searchResults.innerHTML = '';

      if (!searchQuery) {{
        searchResults.style.display = 'none';
        return;
      }}

      const matches = nodes.filter(n => n.n.toLowerCase().includes(searchQuery) || n.p.toLowerCase().includes(searchQuery)).slice(0, 25);
      if (!matches.length) {{
        searchResults.style.display = 'none';
        return;
      }}

      searchResults.style.display = 'block';
      matches.forEach(m => {{
        const el = document.createElement('div');
        el.className = 'search-item';
        el.style.borderLeftColor = m.color;
        el.innerHTML = `
          <span class="search-item-title">${{m.n}}</span>
          <span class="search-item-tag">${{m.sub}} &middot; in:${{m.in}}</span>
        `;
        el.onclick = () => {{
          focusNode(m.i);
          searchResults.style.display = 'none';
          searchInput.value = '';
          searchClear.style.display = 'none';
        }};
        searchResults.appendChild(el);
      }});
    }});

    searchClear.addEventListener('click', () => {{
      searchInput.value = '';
      searchQuery = '';
      searchClear.style.display = 'none';
      searchResults.style.display = 'none';
    }});

    document.addEventListener('click', e => {{
      if (!searchResults.contains(e.target) && e.target !== searchInput) {{
        searchResults.style.display = 'none';
      }}
    }});

    // Subsystem Checklist Filter
    const legendEl = document.getElementById('legend');
    const selectAllCb = document.getElementById('select-all-cb');

    function updateSelectAllState() {{
      const total = Object.keys(SUBSYSTEMS).length;
      const hidden = hiddenSubsystems.size;
      selectAllCb.checked = hidden === 0;
      selectAllCb.indeterminate = hidden > 0 && hidden < total;
    }}

    function toggleAllSubsystems(hide) {{
      document.querySelectorAll('.legend-item').forEach(item => {{
        hide ? item.classList.add('dimmed') : item.classList.remove('dimmed');
      }});
      document.querySelectorAll('.legend-cb').forEach(cb => {{
        cb.checked = !hide;
      }});
      Object.keys(SUBSYSTEMS).forEach(sid => {{
        if (hide) hiddenSubsystems.add(sid); else hiddenSubsystems.delete(sid);
      }});
      updateSelectAllState();
    }}

    selectAllCb.addEventListener('change', () => {{
      toggleAllSubsystems(!selectAllCb.checked);
    }});

    Object.values(SUBSYSTEMS).forEach(c => {{
      const count = nodes.filter(n => n.sub === c.id).length;
      const item = document.createElement('div');
      item.className = 'legend-item';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.className = 'legend-cb';
      cb.checked = true;

      cb.addEventListener('change', (e) => {{
        e.stopPropagation();
        if (cb.checked) {{
          hiddenSubsystems.delete(c.id);
          item.classList.remove('dimmed');
        }} else {{
          hiddenSubsystems.add(c.id);
          item.classList.add('dimmed');
        }}
        updateSelectAllState();
      }});

      item.innerHTML = `
        <div class="legend-dot" style="background:${{c.color}}"></div>
        <span class="legend-label">${{c.icon}} ${{c.name}}</span>
        <span class="legend-count">${{count}}</span>
      `;
      item.prepend(cb);
      item.onclick = (e) => {{
        if (e.target === cb) return;
        cb.checked = !cb.checked;
        cb.dispatchEvent(new Event('change'));
      }};
      legendEl.appendChild(item);
    }});

    // Mouse & Touch Pan / Zoom Interaction
    let isDragging = false;
    let dragStartX = 0;
    let dragStartY = 0;

    canvas.addEventListener('mousedown', (e) => {{
      const rect = canvas.getBoundingClientRect();
      const sx = e.clientX - rect.left;
      const sy = e.clientY - rect.top;
      const wpos = screenToWorld(sx, sy);

      let clicked = null;
      for (let i = nodes.length - 1; i >= 0; i--) {{
        const n = nodes[i];
        if (hiddenSubsystems.has(n.sub)) continue;
        const dx = wpos.x - n.x;
        const dy = wpos.y - n.y;
        const r = Math.max(7.0, n.radius);
        if (dx * dx + dy * dy <= r * r) {{
          clicked = n;
          break;
        }}
      }}

      if (clicked) {{
        selectNode(clicked);
      }} else {{
        isDragging = true;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
      }}
    }});

    window.addEventListener('mousemove', (e) => {{
      if (isDragging) {{
        const dx = e.clientX - dragStartX;
        const dy = e.clientY - dragStartY;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        cameraX += dx;
        cameraY += dy;
        targetCameraX = cameraX;
        targetCameraY = cameraY;
        return;
      }}

      const rect = canvas.getBoundingClientRect();
      const sx = e.clientX - rect.left;
      const sy = e.clientY - rect.top;
      const wpos = screenToWorld(sx, sy);

      hoveredNode = null;
      for (let i = nodes.length - 1; i >= 0; i--) {{
        const n = nodes[i];
        if (hiddenSubsystems.has(n.sub)) continue;
        const dx = wpos.x - n.x;
        const dy = wpos.y - n.y;
        const r = Math.max(7.0, n.radius);
        if (dx * dx + dy * dy <= r * r) {{
          hoveredNode = n;
          break;
        }}
      }}
      canvas.style.cursor = hoveredNode ? 'pointer' : (isDragging ? 'grabbing' : 'grab');
    }});

    window.addEventListener('mouseup', () => {{
      isDragging = false;
    }});

    canvas.addEventListener('wheel', (e) => {{
      e.preventDefault();
      const zoomFactor = e.deltaY < 0 ? 1.15 : 0.87;
      const newZoom = Math.max(0.2, Math.min(6.0, targetZoom * zoomFactor));

      const rect = canvas.getBoundingClientRect();
      const sx = e.clientX - rect.left;
      const sy = e.clientY - rect.top;
      const wpos = screenToWorld(sx, sy);

      targetZoom = newZoom;
      targetCameraX = sx - wpos.x * newZoom;
      targetCameraY = sy - wpos.y * newZoom;
    }}, {{ passive: false }});

    // Layout Buttons
    document.getElementById('layout-island').addEventListener('click', () => {{
      document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
      document.getElementById('layout-island').classList.add('active');
      applyLayout('island');
    }});

    document.getElementById('layout-tier').addEventListener('click', () => {{
      document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
      document.getElementById('layout-tier').classList.add('active');
      applyLayout('tier');
    }});

    document.getElementById('layout-rad').addEventListener('click', () => {{
      document.querySelectorAll('.view-btn').forEach(b => b.classList.remove('active'));
      document.getElementById('layout-rad').classList.add('active');
      applyLayout('rad');
    }});

    document.getElementById('tree-toggle').addEventListener('click', () => {{
      if (isTreeMode) {{
        applyLayout(currentLayout);
      }} else if (selectedNode) {{
        applyTreeLayout(selectedNode);
      }} else {{
        // Pick primary anchor
        const root = nodes.find(n => n.p.includes('app_database.dart')) || nodes[0];
        selectNode(root);
        applyTreeLayout(root);
      }}
    }});

    // Reset Button
    document.getElementById('reset-btn').addEventListener('click', () => {{
      applyLayout(currentLayout);
      selectedNode = null;
      document.getElementById('info-content').innerHTML = '<span class="empty">Click any node or search above to trace callers and dependencies.</span>';
    }});

    // URL Query Parameters Support
    const urlParams = new URLSearchParams(window.location.search);
    const focusParam = urlParams.get('focus');
    const layoutParam = urlParams.get('layout');
    const modeParam = urlParams.get('mode');
    const searchParam = urlParams.get('search');

    if (layoutParam === 'tier') {{
      document.getElementById('layout-tier').click();
    }} else if (layoutParam === 'radar') {{
      document.getElementById('layout-rad').click();
    }}

    if (focusParam) {{
      const m = nodes.find(n => n.n.toLowerCase().includes(focusParam.toLowerCase()));
      if (m) {{
        focusNode(m.i);
        if (modeParam === 'tree') {{
          applyTreeLayout(m);
        }}
      }}
    }}

    if (searchParam) {{
      searchInput.value = searchParam;
      searchInput.dispatchEvent(new Event('input'));
    }}

    // Launch animation
    requestAnimationFrame(animate);
  </script>
</body>
</html>
'''

output_path = 'docs/architecture/code_graph_visualizer.html'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(html_content)

print(f"Master visualizer successfully written to {output_path}! File size: {os.path.getsize(output_path)} bytes")
