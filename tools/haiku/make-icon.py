#!/usr/bin/env python3
"""Encode the upstream Bridge silhouette from dist/bridge.svg as native HVIF.

Uses its original cubic paths and purple fill; gradients/filters are omitted
for a compact icon. HVIF layout: Haiku src/libs/icon/flat_icon (64x64 canvas).
"""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
svg = ET.parse(root / 'dist/bridge.svg').getroot()
path = next(svg.iter('{http://www.w3.org/2000/svg}path'))
tokens = iter(re.findall(r'[MCHVLZ]|-?\d+(?:\.\d+)?', path.attrib['d']))
paths, points = [], []

def coord():
    return float(next(tokens)) / 4

def point():
    return [coord(), coord()]

for command in tokens:
    if command == 'M':
        p = point()
        points = [[p[:], p[:], p[:]]]
    elif command == 'C':
        c1, c2, p = point(), point(), point()
        points[-1][2] = c1
        points.append([p, c2, p[:]])
    elif command in ('L', 'H', 'V'):
        p = point() if command == 'L' else points[-1][0][:]
        if command == 'H': p[0] = coord()
        if command == 'V': p[1] = coord()
        points.append([p[:], p[:], p[:]])
    elif command == 'Z':
        if points[-1][0] == points[0][0]:
            points[0][1] = points.pop()[1]
        paths.append(points)
    else:
        raise ValueError(f'Unexpected path command {command}')

out = bytearray(b'ncif')
out.extend((1, 3, 0x6d, 0x4a, 0xff, len(paths)))  # one RGB style
for points in paths:
    out.extend((2, len(points)))  # closed cubic path
    for vertex in points:
        for xy in vertex:
            for value in xy:
                packed = round((value + 128) * 102)
                assert 0 <= packed <= 32767
                out.extend((0x80 | (packed >> 8), packed & 255))
out.extend((1, 10, 0, len(paths), *range(len(paths)), 0))  # one shape, all subpaths
(root / 'dist/haiku/Bridge.hvif').write_bytes(out)
print(f'Wrote {len(out)} bytes')
