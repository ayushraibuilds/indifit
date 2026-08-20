#!/usr/bin/env python3
"""Convert the pinned MuscleMap Swift path tables into local Dart geometry.

This is a development-time conversion tool. It intentionally accepts a local
checkout/export of the already-reviewed upstream source; it does not fetch
network content and it does not parse SVG at application runtime.

The output contains normalized-independent path commands. Flutter applies the
source viewBox transform at paint time, so the same generated geometry remains
deterministic across screen sizes and device pixel ratios.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


COMMIT = "7dc03071e03052e8bd4f6351e9176994cd28aa7d"
TAG = "1.6.4"

VIEW_DEFINITIONS = (
    ("MaleFrontPaths.swift", "male", "front", 0.0, 95.0, 727.0, 1280.0),
    ("MaleBackPaths.swift", "male", "back", 718.0, 95.0, 727.0, 1280.0),
    ("FemaleFrontPaths.swift", "female", "front", 0.0, 0.0, 650.0, 1450.0),
    ("FemaleBackPaths.swift", "female", "back", 823.0, 0.0, 650.0, 1450.0),
)

TOKEN_RE = re.compile(
    r"[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"
)


@dataclass(frozen=True)
class Command:
    op: str
    values: tuple[float, ...] = ()


def _close_balanced(text: str, start: int, opening: str, closing: str) -> str:
    """Return the balanced block beginning at an opening delimiter."""
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return text[start + 1 : index]
    raise ValueError(f"Unbalanced {opening}{closing} block at {start}")


def _quoted_strings(text: str) -> list[str]:
    values: list[str] = []
    index = 0
    while index < len(text):
        if text[index] != '"':
            index += 1
            continue
        start = index
        index += 1
        escaped = False
        while index < len(text):
            char = text[index]
            index += 1
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                values.append(json.loads(text[start:index]))
                break
        else:
            raise ValueError("Unterminated Swift string")
    return values


def _extract_array(block: str, key: str) -> list[str]:
    match = re.search(rf"\b{re.escape(key)}\s*:\s*\[", block)
    if match is None:
        return []
    opening = block.find("[", match.start())
    return _quoted_strings(_close_balanced(block, opening, "[", "]"))


def extract_body_parts(source: str) -> list[tuple[str, list[str]]]:
    """Extract (slug, all path strings) from a Swift path table."""
    results: list[tuple[str, list[str]]] = []
    marker = "BodyPartPathData("
    cursor = 0
    while True:
        start = source.find(marker, cursor)
        if start == -1:
            break
        opening = source.find("(", start)
        block = _close_balanced(source, opening, "(", ")")
        slug_match = re.search(r"\bslug\s*:\s*\.([A-Za-z0-9_]+)", block)
        if slug_match is None:
            raise ValueError(f"BodyPartPathData block has no slug near {start}")
        slug = _swift_slug(slug_match.group(1))
        paths = (
            _extract_array(block, "common")
            + _extract_array(block, "left")
            + _extract_array(block, "right")
        )
        results.append((slug, paths))
        cursor = opening + len(block) + 2
    if not results:
        raise ValueError("No BodyPartPathData entries found")
    return results


def _swift_slug(value: str) -> str:
    """Convert the enum case spelling to MuscleMap's stable raw-value slug."""
    return {
        "lowerBack": "lower-back",
        "upperBack": "upper-back",
        "rotatorCuff": "rotator-cuff",
        "hipFlexors": "hip-flexors",
        "upperChest": "upper-chest",
        "lowerChest": "lower-chest",
        "innerQuad": "inner-quad",
        "outerQuad": "outer-quad",
        "upperAbs": "upper-abs",
        "lowerAbs": "lower-abs",
        "frontDeltoid": "front-deltoid",
        "rearDeltoid": "rear-deltoid",
        "upperTrapezius": "upper-trapezius",
        "lowerTrapezius": "lower-trapezius",
    }.get(value, value.lower())


def _tokens(path: str) -> list[str]:
    compact = path.replace("\n", " ")
    tokens = TOKEN_RE.findall(compact)
    remainder = TOKEN_RE.sub("", compact)
    if re.sub(r"[\s,]+", "", remainder):
        raise ValueError(f"Unsupported path token in {path[:120]!r}")
    return tokens


def _is_command(token: str) -> bool:
    return len(token) == 1 and token.isalpha()


def parse_path(path: str) -> list[Command]:
    """Parse SVG path commands and resolve relative/smooth/arc commands."""
    tokens = _tokens(path)
    index = 0
    command: str | None = None
    current = (0.0, 0.0)
    subpath_start = current
    last_cubic_control: tuple[float, float] | None = None
    last_quadratic_control: tuple[float, float] | None = None
    previous_command = ""
    output: list[Command] = []
    arities = {
        "M": 2,
        "L": 2,
        "H": 1,
        "V": 1,
        "C": 6,
        "S": 4,
        "Q": 4,
        "T": 2,
        "A": 7,
        "Z": 0,
    }

    def take(count: int) -> list[float]:
        nonlocal index
        if index + count > len(tokens) or any(
            _is_command(token) for token in tokens[index : index + count]
        ):
            raise ValueError(f"Not enough numeric arguments in {path[:160]!r}")
        values = [float(token) for token in tokens[index : index + count]]
        index += count
        return values

    def take_arc_values() -> list[float]:
        nonlocal index
        values = take(3)
        flags: list[float] = []
        for _ in range(2):
            if index >= len(tokens) or _is_command(tokens[index]):
                raise ValueError(f"Missing arc flag in {path[:160]!r}")
            token = tokens[index]
            if len(token) > 1 and token[0] in {"0", "1"}:
                flags.append(float(token[0]))
                remainder = token[1:]
                if remainder:
                    tokens[index] = remainder
                else:
                    index += 1
            else:
                flag = float(token)
                if flag not in (0.0, 1.0):
                    raise ValueError(f"Arc flags must be 0 or 1 in {path[:160]!r}")
                flags.append(flag)
                index += 1
        values.extend(flags)
        values.extend(take(2))
        return values

    def point(x: float, y: float, relative: bool) -> tuple[float, float]:
        return (current[0] + x, current[1] + y) if relative else (x, y)

    while index < len(tokens):
        if _is_command(tokens[index]):
            command = tokens[index]
            index += 1
        if command is None:
            raise ValueError(f"Path starts with numbers: {path[:160]!r}")

        upper = command.upper()
        relative = command.islower()
        if upper not in arities:
            raise ValueError(f"Unsupported SVG command {command!r}")
        if upper == "Z":
            output.append(Command("z"))
            current = subpath_start
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "Z"
            command = None
            continue

        values = take_arc_values() if upper == "A" else take(arities[upper])
        if upper == "M":
            destination = point(values[0], values[1], relative)
            output.append(Command("m", destination))
            current = destination
            subpath_start = destination
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "M"
            command = "l" if relative else "L"
        elif upper == "L":
            destination = point(values[0], values[1], relative)
            output.append(Command("l", destination))
            current = destination
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "L"
        elif upper == "H":
            destination = (current[0] + values[0], current[1]) if relative else (
                values[0],
                current[1],
            )
            output.append(Command("l", destination))
            current = destination
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "H"
        elif upper == "V":
            destination = (current[0], current[1] + values[0]) if relative else (
                current[0],
                values[0],
            )
            output.append(Command("l", destination))
            current = destination
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "V"
        elif upper == "C":
            control1 = point(values[0], values[1], relative)
            control2 = point(values[2], values[3], relative)
            destination = point(values[4], values[5], relative)
            output.append(Command("c", (*control1, *control2, *destination)))
            current = destination
            last_cubic_control = control2
            last_quadratic_control = None
            previous_command = "C"
        elif upper == "S":
            control1 = (
                (2 * current[0] - last_cubic_control[0], 2 * current[1] - last_cubic_control[1])
                if previous_command in ("C", "S") and last_cubic_control is not None
                else current
            )
            control2 = point(values[0], values[1], relative)
            destination = point(values[2], values[3], relative)
            output.append(Command("c", (*control1, *control2, *destination)))
            current = destination
            last_cubic_control = control2
            last_quadratic_control = None
            previous_command = "S"
        elif upper == "Q":
            control = point(values[0], values[1], relative)
            destination = point(values[2], values[3], relative)
            output.append(Command("q", (*control, *destination)))
            current = destination
            last_quadratic_control = control
            last_cubic_control = None
            previous_command = "Q"
        elif upper == "T":
            control = (
                (2 * current[0] - last_quadratic_control[0], 2 * current[1] - last_quadratic_control[1])
                if previous_command in ("Q", "T") and last_quadratic_control is not None
                else current
            )
            destination = point(values[0], values[1], relative)
            output.append(Command("q", (*control, *destination)))
            current = destination
            last_quadratic_control = control
            last_cubic_control = None
            previous_command = "T"
        elif upper == "A":
            destination = point(values[5], values[6], relative)
            output.extend(
                _arc_to_cubics(
                    current,
                    destination,
                    values[0],
                    values[1],
                    values[2],
                    bool(round(values[3])),
                    bool(round(values[4])),
                )
            )
            current = destination
            last_cubic_control = None
            last_quadratic_control = None
            previous_command = "A"
        else:
            raise AssertionError(f"Unhandled SVG command {upper}")

    return output


def _arc_to_cubics(
    start: tuple[float, float],
    end: tuple[float, float],
    rx: float,
    ry: float,
    angle_degrees: float,
    large_arc: bool,
    sweep: bool,
) -> list[Command]:
    """Convert an SVG endpoint arc to one or more cubic Bézier commands."""
    if start == end:
        return []
    rx = abs(rx)
    ry = abs(ry)
    if rx == 0 or ry == 0:
        return [Command("l", end)]

    phi = math.radians(angle_degrees % 360.0)
    cos_phi = math.cos(phi)
    sin_phi = math.sin(phi)
    dx = (start[0] - end[0]) / 2.0
    dy = (start[1] - end[1]) / 2.0
    x1_prime = cos_phi * dx + sin_phi * dy
    y1_prime = -sin_phi * dx + cos_phi * dy

    radii_scale = (x1_prime * x1_prime) / (rx * rx) + (y1_prime * y1_prime) / (ry * ry)
    if radii_scale > 1:
        scale = math.sqrt(radii_scale)
        rx *= scale
        ry *= scale

    numerator = (
        rx * rx * ry * ry
        - rx * rx * y1_prime * y1_prime
        - ry * ry * x1_prime * x1_prime
    )
    denominator = rx * rx * y1_prime * y1_prime + ry * ry * x1_prime * x1_prime
    coefficient = 0.0 if denominator == 0 else math.sqrt(max(0.0, numerator / denominator))
    if large_arc == sweep:
        coefficient = -coefficient
    cx_prime = coefficient * (rx * y1_prime / ry)
    cy_prime = coefficient * (-ry * x1_prime / rx)
    cx = cos_phi * cx_prime - sin_phi * cy_prime + (start[0] + end[0]) / 2.0
    cy = sin_phi * cx_prime + cos_phi * cy_prime + (start[1] + end[1]) / 2.0

    def vector_angle(ux: float, uy: float, vx: float, vy: float) -> float:
        dot = ux * vx + uy * vy
        length = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
        if length == 0:
            return 0.0
        value = max(-1.0, min(1.0, dot / length))
        angle = math.acos(value)
        if ux * vy - uy * vx < 0:
            angle = -angle
        return angle

    ux = (x1_prime - cx_prime) / rx
    uy = (y1_prime - cy_prime) / ry
    vx = (-x1_prime - cx_prime) / rx
    vy = (-y1_prime - cy_prime) / ry
    theta = vector_angle(1, 0, ux, uy)
    delta = vector_angle(ux, uy, vx, vy)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi

    segment_count = max(1, int(math.ceil(abs(delta) / (math.pi / 2))))
    segment_delta = delta / segment_count
    commands: list[Command] = []

    def ellipse_point(angle: float) -> tuple[float, float]:
        cos_angle = math.cos(angle)
        sin_angle = math.sin(angle)
        return (
            cx + cos_phi * rx * cos_angle - sin_phi * ry * sin_angle,
            cy + sin_phi * rx * cos_angle + cos_phi * ry * sin_angle,
        )

    for segment in range(segment_count):
        start_angle = theta + segment * segment_delta
        end_angle = start_angle + segment_delta
        alpha = 4 / 3 * math.tan(segment_delta / 4)
        p0 = ellipse_point(start_angle)
        p3 = ellipse_point(end_angle)
        d0 = (-rx * math.sin(start_angle), ry * math.cos(start_angle))
        d3 = (-rx * math.sin(end_angle), ry * math.cos(end_angle))
        if not sweep:
            d0 = (-d0[0], -d0[1])
            d3 = (-d3[0], -d3[1])
        c1 = (
            p0[0] + alpha * (cos_phi * d0[0] - sin_phi * d0[1]),
            p0[1] + alpha * (sin_phi * d0[0] + cos_phi * d0[1]),
        )
        c2 = (
            p3[0] - alpha * (cos_phi * d3[0] - sin_phi * d3[1]),
            p3[1] - alpha * (sin_phi * d3[0] + cos_phi * d3[1]),
        )
        commands.append(Command("c", (*c1, *c2, *p3)))
    return commands


def _number(value: float) -> str:
    if abs(value) < 0.0000005:
        value = 0.0
    return f"{value:.6f}".rstrip("0").rstrip(".") or "0"


def _dart_command(command: Command) -> str:
    if command.op == "m":
        return (
            "IndiFitMuscleMapPathCommand.move("
            f"{_number(command.values[0])}, {_number(command.values[1])})"
        )
    if command.op == "l":
        return (
            "IndiFitMuscleMapPathCommand.line("
            f"{_number(command.values[0])}, {_number(command.values[1])})"
        )
    if command.op == "q":
        return (
            "IndiFitMuscleMapPathCommand.quadratic("
            + ", ".join(_number(value) for value in command.values)
            + ")"
        )
    if command.op == "c":
        return (
            "IndiFitMuscleMapPathCommand.cubic("
            + ", ".join(_number(value) for value in command.values)
            + ")"
        )
    if command.op == "z":
        return "IndiFitMuscleMapPathCommand.close()"
    raise ValueError(f"Unknown command {command.op}")


def _dart_list(values: Sequence[str]) -> str:
    if not values:
        return "<IndiFitMuscleMapPathCommand>[]"
    lines = [
        "<IndiFitMuscleMapPathCommand>[",
        *[f"      {value}," for value in values],
        "    ]",
    ]
    return "\n".join(lines)


def generate(source_dir: Path) -> str:
    regions: list[str] = []
    total_paths = 0
    total_commands = 0
    for file_name, body, side, _origin_x, _origin_y, _width, _height in VIEW_DEFINITIONS:
        source = (source_dir / file_name).read_text(encoding="utf-8")
        for slug, paths in extract_body_parts(source):
            commands: list[str] = []
            for path in paths:
                parsed = parse_path(path)
                total_paths += 1
                total_commands += len(parsed)
                commands.extend(_dart_command(command) for command in parsed)
            if not commands:
                continue
            region_id = f"{body}_{side}_{slug}"
            path_literal = _dart_list(commands)
            regions.append(
                f"""    IndiFitMuscleMapGeometryRegion(
      regionId: '{region_id}',
      upstreamSlug: '{slug}',
      bodyModel: IndiFitMuscleMapBodyModel.{body},
      side: IndiFitMuscleMapSide.{side},
      paths: {path_literal},
    ),"""
            )

    region_text = "\n".join(regions)
    return (
        f"""// GENERATED FILE - DO NOT EDIT.
//
// Generated by tool/convert_musclemap_geometry.py from MuscleMap {TAG}.
// Pinned commit: {COMMIT}
// Source files: BodyPathData.swift, MaleFrontPaths.swift, MaleBackPaths.swift,
// FemaleFrontPaths.swift, FemaleBackPaths.swift.
// The converter resolves relative/smooth SVG commands and converts arcs to
// cubic Bézier commands; no SVG parser is used by the Flutter runtime.

import 'dart:ui' show Path;

enum IndiFitMuscleMapBodyModel {{ male, female }}

enum IndiFitMuscleMapSide {{ front, back }}

class IndiFitMuscleMapViewBox {{
  const IndiFitMuscleMapViewBox({{
    required this.originX,
    required this.originY,
    required this.width,
    required this.height,
  }});

  final double originX;
  final double originY;
  final double width;
  final double height;
}}

class IndiFitMuscleMapPathCommand {{
  const IndiFitMuscleMapPathCommand.move(this.x1, this.y1)
    : operation = _move,
      x2 = 0,
      y2 = 0,
      x3 = 0,
      y3 = 0,
      x4 = 0,
      y4 = 0;

  const IndiFitMuscleMapPathCommand.line(this.x1, this.y1)
    : operation = _line,
      x2 = 0,
      y2 = 0,
      x3 = 0,
      y3 = 0,
      x4 = 0,
      y4 = 0;

  const IndiFitMuscleMapPathCommand.quadratic(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
  ) : operation = _quadratic,
      x3 = 0,
      y3 = 0,
      x4 = 0,
      y4 = 0;

  const IndiFitMuscleMapPathCommand.cubic(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.x3,
    this.y3,
  ) : operation = _cubic,
      x4 = 0,
      y4 = 0;

  const IndiFitMuscleMapPathCommand.close()
    : operation = _close,
      x1 = 0,
      y1 = 0,
      x2 = 0,
      y2 = 0,
      x3 = 0,
      y3 = 0,
      x4 = 0,
      y4 = 0;

  static const int _move = 0;
  static const int _line = 1;
  static const int _quadratic = 2;
  static const int _cubic = 3;
  static const int _close = 4;

  final int operation;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;
  final double x4;
  final double y4;

  void applyTo(Path path) {{
    switch (operation) {{
      case _move:
        path.moveTo(x1, y1);
      case _line:
        path.lineTo(x1, y1);
      case _quadratic:
        path.quadraticBezierTo(x1, y1, x2, y2);
      case _cubic:
        path.cubicTo(x1, y1, x2, y2, x3, y3);
      case _close:
        path.close();
    }}
  }}
}}

class IndiFitMuscleMapGeometryRegion {{
  const IndiFitMuscleMapGeometryRegion({{
    required this.regionId,
    required this.upstreamSlug,
    required this.bodyModel,
    required this.side,
    required this.paths,
  }});

  final String regionId;
  final String upstreamSlug;
  final IndiFitMuscleMapBodyModel bodyModel;
  final IndiFitMuscleMapSide side;
  final List<IndiFitMuscleMapPathCommand> paths;

  Path toPath() {{
    final path = Path();
    for (final command in paths) {{
      command.applyTo(path);
    }}
    return path;
  }}
}}

abstract final class IndiFitMuscleMapGeometryRegistry {{
  static const String upstreamRepository =
      'https://github.com/melihcolpan/MuscleMap';
  static const String upstreamCommit = '{COMMIT}';
  static const String upstreamTag = '{TAG}';

  static const Map<String, IndiFitMuscleMapViewBox> viewBoxes = {{
    'male_front': IndiFitMuscleMapViewBox(
      originX: 0,
      originY: 95,
      width: 727,
      height: 1280,
    ),
    'male_back': IndiFitMuscleMapViewBox(
      originX: 718,
      originY: 95,
      width: 727,
      height: 1280,
    ),
    'female_front': IndiFitMuscleMapViewBox(
      originX: 0,
      originY: 0,
      width: 650,
      height: 1450,
    ),
    'female_back': IndiFitMuscleMapViewBox(
      originX: 823,
      originY: 0,
      width: 650,
      height: 1450,
    ),
  }};

  static const List<IndiFitMuscleMapGeometryRegion> regions = [
{region_text}
  ];

  static Iterable<IndiFitMuscleMapGeometryRegion> forView(
    IndiFitMuscleMapBodyModel bodyModel,
    IndiFitMuscleMapSide side,
  ) => regions.where(
    (region) => region.bodyModel == bodyModel && region.side == side,
  );

  static String viewBoxKey(
    IndiFitMuscleMapBodyModel bodyModel,
    IndiFitMuscleMapSide side,
  ) => 'DART_DOLLAR{{bodyModel.name}}_DART_DOLLAR{{side.name}}';
}}

// Converted source statistics: {len(regions)} regions, {total_paths} source
// subpaths, {total_commands} resolved draw commands.
        """
    ).replace("DART_DOLLAR", "$")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    generated = generate(arguments.source_dir)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(generated, encoding="utf-8")
    print(
        f"Generated {arguments.output} ({len(generated.splitlines())} lines, "
        f"{len(generated.encode('utf-8'))} bytes)."
    )


if __name__ == "__main__":
    main()
