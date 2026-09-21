#!/usr/bin/env python3
"""
build_referenced_visualizer.py
Upgrades docs/architecture/code_graph_visualizer.html taking direct reference
from graph.html (graphify) found in Downloads:
- Permanent right-hand sidebar with Search dropdown, Node Info, Architectural Communities checklist, and Stats
- Shaded convex hull territories for communities (Andrew's monotone chain)
- Crisp offline Canvas 2D rendering with greedy collision-avoidance landmark labels
- Dual layouts: Constellation + Concentric Radar
- Live Radar Minimap
"""

import re
import os

with open('docs/architecture/code_graph_visualizer.html', 'r', encoding='utf-8') as f:
    orig_html = f.read()

nodes_match = re.search(r'const rawNodes = (\[.*?\]);', orig_html)
edges_match = re.search(r'const rawEdges = (\[.*?\]);', orig_html)

if not nodes_match or not edges_match:
    print("Error: could not extract rawNodes or rawEdges")
    exit(1)

raw_nodes_str = nodes_match.group(1)
raw_edges_str = edges_match.group(1)

html_template = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>IndiFit — Architecture & Knowledge Graph</title>
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      background: #090d16;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      height: 100vh;
      width: 100vw;
      overflow: hidden;
      display: flex;
    }}

    /* Main Canvas Stage */
    #main-stage {{
      flex: 1;
      height: 100vh;
      position: relative;
      overflow: hidden;
      background: radial-gradient(circle at 50% 50%, #0d1527 0%, #080c14 100%);
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
      background: rgba(15, 23, 42, 0.82);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 12px;
      padding: 10px 16px;
      z-index: 10;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
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
      box-shadow: 0 2px 10px rgba(56, 189, 248, 0.3);
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
      gap: 10px;
    }}

    /* Tour Chips */
    .tour-strip {{
      display: flex;
      align-items: center;
      gap: 6px;
      background: rgba(8, 14, 28, 0.6);
      padding: 4px;
      border-radius: 8px;
      border: 1px solid rgba(255, 255, 255, 0.06);
    }}
    .tour-chip {{
      background: transparent;
      border: 1px solid transparent;
      color: #cbd5e1;
      padding: 4px 9px;
      border-radius: 6px;
      font-size: 11px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 4px;
      transition: all 0.15s;
    }}
    .tour-chip:hover {{
      background: rgba(255, 255, 255, 0.08);
      color: #fff;
    }}

    /* View Switcher */
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

    /* Minimap Radar */
    #radar-hud {{
      position: absolute;
      bottom: 16px;
      left: 16px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(12px);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 10px;
      padding: 10px;
      z-index: 10;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.35);
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
      box-shadow: -10px 0 30px rgba(0, 0, 0, 0.3);
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
      box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
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
    #search-clear:hover {{ color: #e2e8f0; }}

    #search-results {{
      position: absolute;
      top: 56px;
      left: 14px;
      right: 14px;
      max-height: 220px;
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

    /* Node Info Panel (Reference from graph.html) */
    #info-panel {{
      padding: 14px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      max-height: 44vh;
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

    /* Metric Grid */
    .metric-grid {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 6px;
      margin-bottom: 12px;
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

    .focus-center-btn {{
      width: 100%;
      background: #6366f1;
      border: none;
      color: #fff;
      font-weight: 600;
      font-size: 11px;
      padding: 6px 10px;
      border-radius: 6px;
      cursor: pointer;
      margin-bottom: 12px;
      transition: background 0.15s;
    }}
    .focus-center-btn:hover {{ background: #4f46e5; }}

    /* Neighbor links (Reference from graph.html) */
    .neighbor-subhead {{
      font-size: 11px;
      font-weight: 700;
      color: #94a3b8;
      margin: 8px 0 4px 0;
      display: flex;
      justify-content: space-between;
    }}
    .neighbors-list {{
      max-height: 120px;
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

    /* Communities / Legend (Direct Reference from graph.html) */
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
      padding: 6px 8px;
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
          <div class="brand-sub">453 Dart Files · 277,731 LOC · 2,198 Internal Edges · 0 P0 Catches</div>
        </div>
      </div>

      <div class="top-controls">
        <div class="tour-strip">
          <span style="font-size:10px;font-weight:700;color:#64748b;padding-left:4px;">FOCUS:</span>
          <button class="tour-chip" data-tour="anchors">⭐ Big 5 Anchors</button>
          <button class="tour-chip" data-tour="workout">🏋️ Workout B02</button>
          <button class="tour-chip" data-tour="nutrition">🍛 Nutrition & Thali</button>
          <button class="tour-chip" data-tour="privacy">🛡️ DPDP & Privacy</button>
          <button class="tour-chip" data-tour="db">💾 Drift SQLite</button>
        </div>

        <div class="view-group">
          <button id="layout-org" class="view-btn active">Constellation</button>
          <button id="layout-rad" class="view-btn">Radar</button>
        </div>

        <button id="reset-btn" class="reset-btn">Reset</button>
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

  <!-- Right Sidebar (Direct Reference from graph.html) -->
  <div id="sidebar">
    <!-- Search Section -->
    <div id="search-wrap">
      <div id="search-input-wrap">
        <input id="search" type="text" placeholder="Search nodes (e.g. thali, db, b05)..." autocomplete="off">
        <button id="search-clear">×</button>
      </div>
      <div id="search-results"></div>
    </div>

    <!-- Node Info Panel -->
    <div id="info-panel">
      <div class="section-title">
        <span>Node Info</span>
        <span id="info-catches" style="color:#10b981;font-size:10px;font-weight:600;">Clean</span>
      </div>
      <div id="info-content">
        <span class="empty">Click a node or search above to inspect architectural details.</span>
      </div>
    </div>

    <!-- Architectural Communities Legend -->
    <div id="legend-wrap">
      <div class="section-title">Architectural Communities</div>
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
      4 communities &middot; 0 P0 catches
    </div>
  </div>

  <script>
    const rawNodes = {raw_nodes_str};
    const rawEdges = {raw_edges_str};

    // Layer metadata & color palette
    const COMMUNITIES = {{
      'features': {{
        id: 'features',
        name: 'Features & Screens',
        color: '#c084fc',
        hullFill: 'rgba(192, 132, 252, 0.06)',
        hullStroke: 'rgba(192, 132, 252, 0.35)',
        count: 196
      }},
      'core': {{
        id: 'core',
        name: 'Core Domain & Engines',
        color: '#34d399',
        hullFill: 'rgba(52, 211, 153, 0.06)',
        hullStroke: 'rgba(52, 211, 153, 0.35)',
        count: 130
      }},
      'data': {{
        id: 'data',
        name: 'Data & SQLite v22',
        color: '#fbbf24',
        hullFill: 'rgba(251, 191, 36, 0.06)',
        hullStroke: 'rgba(251, 191, 36, 0.35)',
        count: 124
      }},
      'app': {{
        id: 'app',
        name: 'App Bootstrap / Root',
        color: '#38bdf8',
        hullFill: 'rgba(56, 189, 248, 0.06)',
        hullStroke: 'rgba(56, 189, 248, 0.35)',
        count: 3
      }}
    }};

    // Key architectural pillars for prominent landmark labels
    const keyPillars = new Set([
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
    ]);

    // Prepare node structures
    const nodes = rawNodes.map(n => {{
      const isAnchor = n.in >= 25 || keyPillars.has(n.n);
      const radius = isAnchor ? Math.max(7.0, Math.min(18.0, 5.0 + Math.sqrt(n.in) * 1.3)) : Math.max(3.5, Math.min(14.0, 3.5 + Math.sqrt(n.in) * 1.1));
      return {{
        ...n,
        x: n.x_org,
        y: n.y_org,
        targetX: n.x_org,
        targetY: n.y_org,
        radius,
        color: COMMUNITIES[n.l] ? COMMUNITIES[n.l].color : '#94a3b8',
        isAnchor
      }};
    }});

    // Build fast lookup by node id
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
    let cameraY = height / 2 + 10;
    let zoom = Math.min(width, height) / 1200;
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
    let currentLayout = 'constellation';
    let searchQuery = '';
    const hiddenCommunities = new Set();

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

    // Main Render Loop
    let pulse = 0;
    function animate() {{
      pulse += 0.035;

      // Smooth camera interpolation
      cameraX += (targetCameraX - cameraX) * 0.12;
      cameraY += (targetCameraY - cameraY) * 0.12;
      zoom += (targetZoom - zoom) * 0.12;

      // Smooth node position interpolation
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

      // Subtle Background Grid
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

      // PASS 0: Shaded Community Convex Hulls (Direct Reference from graph.html)
      if (currentLayout === 'constellation') {{
        for (const [layerKey, layerInfo] of Object.entries(COMMUNITIES)) {{
          if (hiddenCommunities.has(layerKey)) continue;
          const layerNodes = nodes.filter(n => n.l === layerKey);
          if (layerNodes.length < 3) continue;

          const pts = layerNodes.map(n => worldToScreen(n.x, n.y));
          const cx = pts.reduce((s, p) => s + p.x, 0) / pts.length;
          const cy = pts.reduce((s, p) => s + p.y, 0) / pts.length;
          const hull = convexHull(pts);
          if (hull.length < 3) continue;

          // Expand hull by 12% for comfortable padding
          const expanded = hull.map(p => ({{
            x: cx + (p.x - cx) * 1.12,
            y: cy + (p.y - cy) * 1.12
          }}));

          ctx.save();
          ctx.beginPath();
          ctx.moveTo(expanded[0].x, expanded[0].y);
          for (let j = 1; j < expanded.length; j++) {{
            ctx.lineTo(expanded[j].x, expanded[j].y);
          }}
          ctx.closePath();
          ctx.fillStyle = layerInfo.hullFill;
          ctx.fill();
          ctx.strokeStyle = layerInfo.hullStroke;
          ctx.lineWidth = 1.2;
          ctx.setLineDash([4, 4]);
          ctx.stroke();

          // Territory Title Label
          if (zoom > 0.45 && zoom < 1.7) {{
            ctx.font = '700 11px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';
            ctx.fillStyle = layerInfo.color;
            ctx.globalAlpha = 0.45;
            ctx.textAlign = 'center';
            ctx.fillText(layerInfo.name.toUpperCase(), cx, cy - 10);
          }}
          ctx.restore();
        }}
      }}

      // PASS 1: Edges
      for (let i = 0; i < rawEdges.length; i++) {{
        const [sourceId, targetId] = rawEdges[i];
        const sNode = nodeMap.get(sourceId);
        const tNode = nodeMap.get(targetId);
        if (!sNode || !tNode) continue;
        if (hiddenCommunities.has(sNode.l) || hiddenCommunities.has(tNode.l)) continue;

        const sPos = worldToScreen(sNode.x, sNode.y);
        const tPos = worldToScreen(tNode.x, tNode.y);

        const isHighlight = selectedNode && (
          (selectedNode.i === sNode.i && selectedNode.imports.includes(tNode.i)) ||
          (selectedNode.i === tNode.i && selectedNode.imported_by.includes(sNode.i))
        );

        ctx.save();
        if (isHighlight) {{
          ctx.strokeStyle = '#38bdf8';
          ctx.lineWidth = 1.8;
          ctx.globalAlpha = 0.85;
        }} else if (selectedNode) {{
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.02)';
          ctx.lineWidth = 0.4;
          ctx.globalAlpha = 0.15;
        }} else {{
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)';
          ctx.lineWidth = 0.6;
          ctx.globalAlpha = 0.5;
        }}

        // Elegant curved bezier
        ctx.beginPath();
        ctx.moveTo(sPos.x, sPos.y);
        const mx = (sPos.x + tPos.x) / 2;
        const my = (sPos.y + tPos.y) / 2;
        const dx = tPos.x - sPos.x;
        const dy = tPos.y - sPos.y;
        ctx.quadraticCurveTo(mx - dy * 0.08, my + dx * 0.08, tPos.x, tPos.y);
        ctx.stroke();
        ctx.restore();
      }}

      // PASS 2: Nodes
      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        if (hiddenCommunities.has(n.l)) continue;

        const pos = worldToScreen(n.x, n.y);
        const isSelected = selectedNode && selectedNode.i === n.i;
        const isHovered = hoveredNode && hoveredNode.i === n.i;
        const isConnected = selectedNode && (selectedNode.imports.includes(n.i) || selectedNode.imported_by.includes(n.i));

        let alpha = 1.0;
        if (searchQuery) {{
          alpha = (n.n.toLowerCase().includes(searchQuery) || n.p.toLowerCase().includes(searchQuery)) ? 1.0 : 0.15;
        }} else if (selectedNode && !isSelected && !isConnected) {{
          alpha = 0.2;
        }}

        ctx.save();
        ctx.globalAlpha = alpha;

        const r = Math.max(3.0, n.radius * zoom);

        // Orbit ring for major anchors
        if (n.isAnchor && !selectedNode) {{
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

        // Selection / Hover ring
        if (isSelected || isHovered) {{
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, r + 5, 0, Math.PI * 2);
          ctx.fillStyle = isSelected ? 'rgba(99, 102, 241, 0.4)' : 'rgba(255, 255, 255, 0.2)';
          ctx.fill();
        }}

        // Solid Node Core
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, r, 0, Math.PI * 2);
        ctx.fillStyle = n.color;
        ctx.fill();

        // Crisp Specular Border
        ctx.lineWidth = isSelected ? 2.5 : 1.2;
        ctx.strokeStyle = isSelected ? '#ffffff' : (isConnected ? '#38bdf8' : 'rgba(255, 255, 255, 0.45)');
        ctx.stroke();

        ctx.restore();
      }}

      // PASS 3: Dynamic Non-Overlapping Landmark Labels (Greedy Collision Avoidance)
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
        if (hiddenCommunities.has(n.l)) continue;
        const isSelected = selectedNode && selectedNode.i === n.i;
        const isHovered = hoveredNode && hoveredNode.i === n.i;
        const isAnchor = n.isAnchor;
        if (isSelected || isHovered || isAnchor || zoom > 1.25) {{
          let priority = n.in || 0;
          if (isSelected) priority += 10000;
          else if (isHovered) priority += 5000;
          else if (isAnchor) priority += 1000;
          candidates.push({{ n, isSelected, isHovered, isAnchor, priority }});
        }}
      }}
      candidates.sort((a, b) => b.priority - a.priority);

      for (let i = 0; i < candidates.length; i++) {{
        const {{ n, isSelected, isHovered, isAnchor }} = candidates[i];
        const pos = worldToScreen(n.x, n.y);
        const r = Math.max(3.0, n.radius * zoom);
        const fs = Math.max(10, Math.min(12, Math.round(11 * Math.sqrt(zoom))));
        ctx.font = `600 ${{fs}}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
        const text = n.n;
        const tw = ctx.measureText(text).width;
        const boxW = tw + 24;
        const boxH = fs + 8;
        const box = {{
          x: pos.x - boxW / 2,
          y: pos.y + r + 5,
          w: boxW,
          h: boxH
        }};

        if (!isSelected && !isHovered) {{
          if (collidesWithPlaced({{ x: box.x - 4, y: box.y - 3, w: box.w + 8, h: box.h + 6 }})) {{
            continue;
          }}
        }}
        placedBoxes.push(box);

        ctx.save();
        let alpha = 1.0;
        if (searchQuery) {{
          alpha = (n.n.toLowerCase().includes(searchQuery) || n.p.toLowerCase().includes(searchQuery)) ? 1.0 : 0.15;
        }} else if (selectedNode && !isSelected && !selectedNode.imports.includes(n.i) && !selectedNode.imported_by.includes(n.i)) {{
          alpha = 0.2;
        }}
        ctx.globalAlpha = alpha;

        // Pill container
        ctx.fillStyle = 'rgba(8, 14, 28, 0.94)';
        ctx.strokeStyle = isSelected ? '#ffffff' : (isAnchor ? n.color : 'rgba(255, 255, 255, 0.22)');
        ctx.lineWidth = isSelected ? 1.8 : (isAnchor ? 1.2 : 0.8);
        ctx.beginPath();
        ctx.roundRect(box.x, box.y, box.w, box.h, 5);
        ctx.fill();
        ctx.stroke();

        // Node category indicator dot inside pill
        ctx.beginPath();
        ctx.arc(box.x + 8, box.y + box.h / 2, 2.5, 0, Math.PI * 2);
        ctx.fillStyle = n.color;
        ctx.fill();

        // Label text
        ctx.fillStyle = isSelected ? '#ffffff' : (isHovered ? '#38bdf8' : (isAnchor ? '#f8fafc' : '#cbd5e1'));
        ctx.textAlign = 'left';
        ctx.fillText(text, box.x + 15, box.y + fs - 1);
        ctx.restore();
      }}

      // PASS 4: Minimap Radar
      miniCtx.clearRect(0, 0, 140, 90);
      const minBounds = {{ x1: -650, y1: -450, x2: 650, y2: 450 }};
      const sx = 140 / (minBounds.x2 - minBounds.x1);
      const sy = 90 / (minBounds.y2 - minBounds.y1);

      let visibleCount = 0;
      for (let i = 0; i < nodes.length; i++) {{
        const n = nodes[i];
        if (hiddenCommunities.has(n.l)) continue;
        visibleCount++;
        const mx = (n.x - minBounds.x1) * sx;
        const my = (n.y - minBounds.y1) * sy;
        miniCtx.fillStyle = n.color;
        miniCtx.fillRect(mx, my, 1.5, 1.5);
      }}
      document.getElementById('mini-count').textContent = `${{visibleCount}} Nodes`;

      // Camera viewport rectangle in minimap
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

    // Node Selection & Inspection (Reference from graph.html)
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
      const comm = COMMUNITIES[n.l] || {{ name: 'Unknown', color: '#94a3b8' }};
      
      const callerLinks = n.imported_by.map(idx => {{
        const caller = nodeMap.get(idx);
        if (!caller) return '';
        return `<div class="neighbor-link" style="border-left-color:${{caller.color}};" onclick="focusNode(${{caller.i}})">
          <span class="neighbor-name">← ${{caller.n}}</span>
          <span class="neighbor-layer">${{caller.l}}</span>
        </div>`;
      }}).join('');

      const calleeLinks = n.imports.map(idx => {{
        const callee = nodeMap.get(idx);
        if (!callee) return '';
        return `<div class="neighbor-link" style="border-left-color:${{callee.color}};" onclick="focusNode(${{callee.i}})">
          <span class="neighbor-name">→ ${{callee.n}}</span>
          <span class="neighbor-layer">${{callee.l}}</span>
        </div>`;
      }}).join('');

      document.getElementById('info-catches').textContent = n.ec > 0 ? `${{n.ec}} Empty Catches` : 'Clean AST';
      document.getElementById('info-catches').style.color = n.ec > 0 ? '#ef4444' : '#10b981';

      document.getElementById('info-content').innerHTML = `
        <div class="node-header-row">
          <span class="node-title">${{n.n}}</span>
          <span class="layer-tag" style="background:${{comm.color}}22;color:${{comm.color}};border:1px solid ${{comm.color}}44;">${{comm.name}}</span>
        </div>
        <div class="node-path">${{n.p}}</div>

        <div class="metric-grid">
          <div class="metric-box">
            <div class="metric-val">${{n.loc.toLocaleString()}}</div>
            <div class="metric-lbl">Lines</div>
          </div>
          <div class="metric-box">
            <div class="metric-val">${{n.in}}</div>
            <div class="metric-lbl">Callers</div>
          </div>
          <div class="metric-box">
            <div class="metric-val">${{n.out}}</div>
            <div class="metric-lbl">Imports</div>
          </div>
        </div>

        <button class="focus-center-btn" onclick="focusNode(${{n.i}})">Focus & Center</button>

        <div class="neighbor-subhead">
          <span>Imported By (Callers)</span>
          <span style="font-family:monospace;">${{n.in}}</span>
        </div>
        <div class="neighbors-list">
          ${{callerLinks || '<div style="color:#64748b;font-style:italic;padding:4px 0;">No callers (leaf/entry)</div>'}}
        </div>

        <div class="neighbor-subhead">
          <span>Imports (Dependencies)</span>
          <span style="font-family:monospace;">${{n.out}}</span>
        </div>
        <div class="neighbors-list">
          ${{calleeLinks || '<div style="color:#64748b;font-style:italic;padding:4px 0;">No internal imports</div>'}}
        </div>
      `;
    }}

    // Search Autocomplete (Direct Reference from graph.html)
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
          <span class="search-item-tag">${{m.l}} &middot; in:${{m.in}}</span>
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

    // Communities Legend & Checkboxes (Direct Reference from graph.html)
    const legendEl = document.getElementById('legend');
    const selectAllCb = document.getElementById('select-all-cb');

    function updateSelectAllState() {{
      const total = Object.keys(COMMUNITIES).length;
      const hidden = hiddenCommunities.size;
      selectAllCb.checked = hidden === 0;
      selectAllCb.indeterminate = hidden > 0 && hidden < total;
    }}

    function toggleAllCommunities(hide) {{
      document.querySelectorAll('.legend-item').forEach(item => {{
        hide ? item.classList.add('dimmed') : item.classList.remove('dimmed');
      }});
      document.querySelectorAll('.legend-cb').forEach(cb => {{
        cb.checked = !hide;
      }});
      Object.keys(COMMUNITIES).forEach(cid => {{
        if (hide) hiddenCommunities.add(cid); else hiddenCommunities.delete(cid);
      }});
      updateSelectAllState();
    }}

    selectAllCb.addEventListener('change', () => {{
      toggleAllCommunities(!selectAllCb.checked);
    }});

    Object.values(COMMUNITIES).forEach(c => {{
      const item = document.createElement('div');
      item.className = 'legend-item';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.className = 'legend-cb';
      cb.checked = true;

      cb.addEventListener('change', (e) => {{
        e.stopPropagation();
        if (cb.checked) {{
          hiddenCommunities.delete(c.id);
          item.classList.remove('dimmed');
        }} else {{
          hiddenCommunities.add(c.id);
          item.classList.add('dimmed');
        }}
        updateSelectAllState();
      }});

      item.innerHTML = `
        <div class="legend-dot" style="background:${{c.color}}"></div>
        <span class="legend-label">${{c.name}}</span>
        <span class="legend-count">${{c.count}}</span>
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

      // Check if clicking a node
      let clicked = null;
      for (let i = nodes.length - 1; i >= 0; i--) {{
        const n = nodes[i];
        if (hiddenCommunities.has(n.l)) continue;
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

      // Hover check
      const rect = canvas.getBoundingClientRect();
      const sx = e.clientX - rect.left;
      const sy = e.clientY - rect.top;
      const wpos = screenToWorld(sx, sy);

      hoveredNode = null;
      for (let i = nodes.length - 1; i >= 0; i--) {{
        const n = nodes[i];
        if (hiddenCommunities.has(n.l)) continue;
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

    // Layout Switchers
    document.getElementById('layout-org').addEventListener('click', () => {{
      currentLayout = 'constellation';
      document.getElementById('layout-org').classList.add('active');
      document.getElementById('layout-rad').classList.remove('active');
      targetZoom = Math.min(width, height) / 1200;
      targetCameraX = width / 2;
      targetCameraY = height / 2 + 10;
      nodes.forEach(n => {{ n.targetX = n.x_org; n.targetY = n.y_org; }});
    }});

    document.getElementById('layout-rad').addEventListener('click', () => {{
      currentLayout = 'radar';
      document.getElementById('layout-rad').classList.add('active');
      document.getElementById('layout-org').classList.remove('active');
      targetZoom = Math.min(width, height) / 1450;
      targetCameraX = width / 2;
      targetCameraY = height / 2 + 25;
      nodes.forEach(n => {{ n.targetX = n.x_rad; n.targetY = n.y_rad; }});
    }});

    // Reset Button
    document.getElementById('reset-btn').addEventListener('click', () => {{
      targetCameraX = width / 2;
      targetCameraY = height / 2 + 10;
      targetZoom = Math.min(width, height) / 1200;
      selectedNode = null;
      document.getElementById('info-content').innerHTML = '<span class="empty">Click a node or search above to inspect architectural details.</span>';
    }});

    // Quick Tours
    const tours = {{
      anchors: 'b05_semantic_colors.dart',
      workout: 'b02_strength_player_screen.dart',
      nutrition: 'circular_thali_plate.dart',
      privacy: 'dpdp_consent_dialog.dart',
      db: 'app_database.dart'
    }};

    document.querySelectorAll('.tour-chip').forEach(btn => {{
      btn.addEventListener('click', () => {{
        const target = tours[btn.dataset.tour];
        const m = nodes.find(n => n.n === target);
        if (m) focusNode(m.i);
      }});
    }});

    // URL Query Parameters Support
    const urlParams = new URLSearchParams(window.location.search);
    const focusParam = urlParams.get('focus');
    const tourParam = urlParams.get('tour');
    const layoutParam = urlParams.get('layout');

    if (layoutParam === 'radar') {{
      document.getElementById('layout-rad').click();
    }}

    if (tourParam && tours[tourParam]) {{
      const m = nodes.find(n => n.n === tours[tourParam]);
      if (m) focusNode(m.i);
    }} else if (focusParam) {{
      const m = nodes.find(n => n.n.toLowerCase().includes(focusParam.toLowerCase()));
      if (m) focusNode(m.i);
    }}

    const searchParam = urlParams.get('search');
    if (searchParam) {{
      searchInput.value = searchParam;
      searchInput.dispatchEvent(new Event('input'));
    }}

    // Launch animation loop
    requestAnimationFrame(animate);
  </script>
</body>
</html>
'''

output_path = 'docs/architecture/code_graph_visualizer.html'
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(html_template)

print(f"Successfully generated reference-enhanced visualizer at {{output_path}}! Size: {{os.path.getsize(output_path)}} bytes")
