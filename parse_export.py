#!/usr/bin/env python3
"""
Parse an Arma 3 editor export (SQF) and generate a composition for use in a mission file.

Handles:
- createVehicle ["ClassName",[x,y,z],[],0,"CAN_COLLIDE"]
- createSimpleObject ["ClassName",[x,y,z]]
- setVectorDirAndUp [[vdx,vdy,vdz],[vux,vuy,vuz]]
- Special properties: allowDamage, enableSimulation, animate, ACE, textures, ammo boxes, etc.

Usage:
    python3 parse_export.py [input_file] [output_file]
    python3 parse_export.py                          # reads export.sqf, writes composition_output.sqf
    cat export.sqf | python3 parse_export.py -       # reads from stdin
"""

import re
import sys
import os

# VR map ground level ASL
VR_GROUND_ASL = 5.0

# Threshold for rounding near-zero z values
Z_EPSILON = 1e-4


def parse_number(s):
    """Parse a number string, handling scientific notation like 4.76837e-07."""
    return float(s.strip())


def format_num(v):
    """Format a number for SQF output."""
    if abs(v) < Z_EPSILON:
        return "0"
    # Remove trailing zeros but keep at least one decimal if float
    formatted = f"{v:.6f}".rstrip('0').rstrip('.')
    # If it's an integer value, just return int form
    if '.' not in formatted:
        return formatted
    return formatted


def parse_vector(s):
    """Parse a vector like [x,y,z] from a string. Returns list of floats."""
    s = s.strip()
    if s.startswith('['):
        s = s[1:]
    if s.endswith(']'):
        s = s[:-1]
    parts = s.split(',')
    return [parse_number(p) for p in parts]


def find_matching_bracket(text, start):
    """Find the matching closing bracket for an opening bracket at position start."""
    depth = 0
    i = start
    while i < len(text):
        if text[i] == '[':
            depth += 1
        elif text[i] == ']':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def extract_vector_dir_and_up(text):
    """Extract vecDir and vecUp from setVectorDirAndUp [[d],[u]]."""
    m = re.search(r'setVectorDirAndUp\s*\[', text)
    if not m:
        return None, None
    # Find the outer bracket
    outer_start = m.end() - 1
    outer_end = find_matching_bracket(text, outer_start)
    if outer_end < 0:
        return None, None
    inner = text[outer_start + 1:outer_end]
    # Find first vector [...]
    m1 = re.search(r'\[', inner)
    if not m1:
        return None, None
    end1 = find_matching_bracket(inner, m1.start())
    vec_dir = parse_vector(inner[m1.start():end1 + 1])
    # Find second vector [...]
    rest = inner[end1 + 1:]
    m2 = re.search(r'\[', rest)
    if not m2:
        return None, None
    end2 = find_matching_bracket(rest, m2.start())
    vec_up = parse_vector(rest[m2.start():end2 + 1])
    return vec_dir, vec_up


def parse_export(text):
    """Parse the entire export text and return a list of object dicts."""
    objects = []

    # Split text into item blocks.
    # Each item starts with a line like: private _itemN = objNull;
    # We split on these boundaries to get per-item blocks.
    # Pattern: lines starting with private _item followed by code until next private _item
    item_pattern = re.compile(r'(private\s+_item\d+\s*=\s*objNull\s*;)', re.IGNORECASE)
    parts = item_pattern.split(text)

    # Reconstruct blocks: each block is the declaration + the code following it
    blocks = []
    i = 0
    while i < len(parts):
        if item_pattern.match(parts[i].strip()):
            block = parts[i]
            if i + 1 < len(parts):
                block += parts[i + 1]
                i += 2
            else:
                i += 1
            blocks.append(block)
        else:
            i += 1

    for block in blocks:
        obj = parse_item_block(block)
        if obj:
            objects.append(obj)

    return objects


def parse_item_block(block):
    """Parse a single item block and return an object dict, or None to skip."""
    obj = {}

    # Extract item variable name
    m = re.search(r'private\s+(_item\d+)', block)
    if not m:
        return None
    item_var = m.group(1)

    # Check for createVehicle
    cv_match = re.search(
        r'createVehicle\s*\[\s*"([^"]+)"\s*,\s*\[([^\]]+)\]',
        block
    )
    # Check for createSimpleObject
    cso_match = re.search(
        r'createSimpleObject\s*\[\s*"([^"]+)"\s*,\s*\[([^\]]+)\]',
        block
    )

    if cv_match:
        obj['type'] = 'vehicle'
        obj['class'] = cv_match.group(1)
        pos = parse_vector(cv_match.group(2))
        # For createVehicle, z is already ATL-like (relative)
        # Round near-zero z
        if abs(pos[2]) < Z_EPSILON:
            pos[2] = 0.0
        obj['pos'] = pos
    elif cso_match:
        obj['type'] = 'simple'
        obj['class'] = cso_match.group(1)
        pos = parse_vector(cso_match.group(2))
        # For createSimpleObject on VR, z is ASL, convert to ATL
        z_atl = pos[2] - VR_GROUND_ASL
        # Round to 2 decimal places for simple objects
        z_atl = round(z_atl, 2)
        if abs(z_atl) < Z_EPSILON:
            z_atl = 0.0
        pos[2] = z_atl
        obj['pos'] = pos
    else:
        return None

    # Extract vectorDirAndUp
    vec_dir, vec_up = extract_vector_dir_and_up(block)
    if vec_dir:
        obj['vecDir'] = vec_dir
    else:
        obj['vecDir'] = [0, 1, 0]
    if vec_up:
        obj['vecUp'] = vec_up
    else:
        obj['vecUp'] = [0, 0, 1]

    # Parse special properties
    obj['props'] = []

    # allowDamage false
    if re.search(r'allowDamage\s+false', block, re.IGNORECASE):
        obj['props'].append('allowDamage false')

    # enableSimulation false
    if re.search(r'enableSimulation\s+false', block, re.IGNORECASE):
        obj['props'].append('enableSimulation false')

    # enableDynamicSimulation true
    if re.search(r'enableDynamicSimulation\s+true', block, re.IGNORECASE):
        obj['props'].append('enableDynamicSimulation true')

    # animate calls (but not animateSource in 3DEN context)
    for am in re.finditer(r'((?:' + re.escape(item_var) + r'|_item\d+)\s+animate(?:Source)?\s*\[[^\]]*\])\s*;', block):
        line = am.group(1).strip()
        # Normalize variable name to _o
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    # setVariable calls (ACE etc.) - but skip 3DEN-only ones
    for sv in re.finditer(
        r'(' + re.escape(item_var) + r'\s+setVariable\s*\[[^\]]*\])\s*;', block
    ):
        line = sv.group(1).strip()
        # Skip editor-only variables
        if 'bis_fnc_3DENAttributeDoorStates' in line.lower():
            continue
        if 'BIS_fnc_3DENAttributeDoorStates' in line:
            continue
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    # setObjectTextureGlobal calls
    for tm in re.finditer(
        r'(' + re.escape(item_var) + r'\s+setObjectTextureGlobal\s*\[[^\]]*\])\s*;', block
    ):
        line = tm.group(1).strip()
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    # bis_fnc_initAmmoBox
    if re.search(r'bis_fnc_initAmmoBox', block, re.IGNORECASE):
        # Extract the full call
        for am in re.finditer(r'(\[[^\]]*\]\s*call\s+bis_fnc_initAmmoBox)\s*;', block, re.IGNORECASE):
            line = am.group(1).strip()
            line = re.sub(r'_item\d+', '_o', line)
            line = re.sub(r'\b_this\b', '_o', line)
            obj['props'].append(line + ';')

    # ACE cargo setSize
    for am in re.finditer(
        r'(\[[^\]]*\]\s*call\s+ace_cargo_fnc_setSize)\s*;', block, re.IGNORECASE
    ):
        line = am.group(1).strip()
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    # ACE rearm makeSource
    for am in re.finditer(
        r'(\[[^\]]*\]\s*call\s+ace_rearm_fnc_makeSource)\s*;', block, re.IGNORECASE
    ):
        line = am.group(1).strip()
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    # ACE refuel makeSource
    for am in re.finditer(
        r'(\[[^\]]*\]\s*call\s+ace_refuel_fnc_makeSource)\s*;', block, re.IGNORECASE
    ):
        line = am.group(1).strip()
        line = re.sub(r'_item\d+', '_o', line)
        line = re.sub(r'\b_this\b', '_o', line)
        obj['props'].append(line + ';')

    return obj


def format_vector(v):
    """Format a vector as SQF [x,y,z]."""
    return '[' + ','.join(format_num(c) for c in v) + ']'


def generate_output(objects):
    """Generate the composition SQF output."""
    lines = []
    lines.append('// Auto-generated composition from editor export')
    lines.append('// Generated by parse_export.py')
    lines.append('')
    lines.append('if (isNil "DYN_ground_objects") then { DYN_ground_objects = []; };')
    lines.append('')
    lines.append('// Helper: create object with rotation (all use createVehicle for ATL positioning)')
    lines.append('private _cv = {')
    lines.append('    params ["_t","_p","_d","_u"];')
    lines.append('    private _o = createVehicle [_t,_p,[],0,"CAN_COLLIDE"];')
    lines.append('    _o setVectorDirAndUp [_d,_u];')
    lines.append('    DYN_ground_objects pushBack _o;')
    lines.append('    _o')
    lines.append('};')
    lines.append('')
    lines.append('private _o = objNull;')
    lines.append('')

    for i, obj in enumerate(objects):
        class_name = obj['class']
        pos = format_vector(obj['pos'])
        vd = format_vector(obj['vecDir'])
        vu = format_vector(obj['vecUp'])

        helper = '_cv'  # All objects use createVehicle for proper ATL positioning
        has_props = len(obj['props']) > 0

        call_str = f'["{class_name}",{pos},{vd},{vu}] call {helper}'

        if has_props:
            lines.append(f'_o = {call_str};')
            for prop in obj['props']:
                if prop == 'allowDamage false':
                    lines.append('_o allowDamage false;')
                elif prop == 'enableSimulation false':
                    lines.append('_o enableSimulation false;')
                elif prop == 'enableDynamicSimulation true':
                    lines.append('_o enableDynamicSimulation true;')
                else:
                    lines.append(prop)
        else:
            lines.append(f'{call_str};')

        lines.append('')

    # Summary
    lines.append(f'// Total: {len(objects)} objects (all createVehicle for ATL positioning)')

    return '\n'.join(lines)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_input = os.path.join(script_dir, 'export.sqf')
    default_output = os.path.join(script_dir, 'composition_output.sqf')

    if len(sys.argv) >= 2 and sys.argv[1] == '-':
        text = sys.stdin.read()
    elif len(sys.argv) >= 2:
        input_file = sys.argv[1]
        with open(input_file, 'r') as f:
            text = f.read()
    else:
        input_file = default_input
        if not os.path.exists(input_file):
            print(f"Error: {input_file} not found.", file=sys.stderr)
            print(f"Usage: python3 {sys.argv[0]} [input_file] [output_file]", file=sys.stderr)
            print(f"       cat export.sqf | python3 {sys.argv[0]} -", file=sys.stderr)
            sys.exit(1)
        with open(input_file, 'r') as f:
            text = f.read()

    output_file = sys.argv[2] if len(sys.argv) >= 3 else default_output

    objects = parse_export(text)
    output = generate_output(objects)

    with open(output_file, 'w') as f:
        f.write(output)

    print(f"Parsed {len(objects)} objects", file=sys.stderr)
    vehicle_count = sum(1 for o in objects if o['type'] == 'vehicle')
    simple_count = sum(1 for o in objects if o['type'] == 'simple')
    print(f"  {vehicle_count} createVehicle objects", file=sys.stderr)
    print(f"  {simple_count} createSimpleObject objects", file=sys.stderr)

    props_count = sum(1 for o in objects if o['props'])
    print(f"  {props_count} objects with special properties", file=sys.stderr)
    print(f"Output written to: {output_file}", file=sys.stderr)


if __name__ == '__main__':
    main()
