#!/usr/bin/env python3
"""Read (never rewrite) an APK's compiled manifest and validate SENJIN's GPU contract.

The prebuilt-APK exporter emitted Vulkan required/version values as TYPE_STRING.
A successful signature check does not catch that error. Gradle/AAPT2 must compile
required as TYPE_INT_BOOLEAN and version as TYPE_INT_DEC/HEX. Vulkan stays optional
because the project's Compatibility renderer is a supported fallback.

This small reader handles Android's string pool and XML start-element chunks only;
it is not a general Android package parser. No third-party Python modules required.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys
import zipfile

ANDROID = 'http://schemas.android.com/apk/res/android'
NO_INDEX = 0xFFFFFFFF
STRING, INT_DEC, INT_HEX, BOOLEAN = 3, 16, 17, 18


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _strings(chunk: bytes, header: int) -> list[str]:
    require(header >= 28 and len(chunk) >= header, 'Invalid string-pool header')
    count, _styles, flags, start, style_start = struct.unpack_from('<5I', chunk, 8)
    end = style_start or len(chunk)
    require(header + count * 4 <= start <= end <= len(chunk), 'Invalid string-pool bounds')

    def length(pos: int, utf8: bool) -> tuple[int, int]:
        unit, mask = (1, 0x80) if utf8 else (2, 0x8000)
        require(pos + unit <= end, 'Truncated string length')
        a = int.from_bytes(chunk[pos:pos + unit], 'little')
        pos += unit
        if a & mask:
            require(pos + unit <= end, 'Truncated extended string length')
            b = int.from_bytes(chunk[pos:pos + unit], 'little')
            return ((a & (mask - 1)) << (8 * unit)) | b, pos + unit
        return a, pos

    result = []
    for i in range(count):
        offset = struct.unpack_from('<I', chunk, header + i * 4)[0]
        pos = start + offset
        require(start <= pos < end, 'Invalid string offset')
        utf8 = bool(flags & 0x100)
        chars, pos = length(pos, utf8)
        size, pos = length(pos, True) if utf8 else (chars * 2, pos)
        terminator = 1 if utf8 else 2
        require(pos + size + terminator <= end, 'Truncated string data')
        require(chunk[pos + size:pos + size + terminator] == b'\0' * terminator,
                'Unterminated string')
        result.append(chunk[pos:pos + size].decode('utf-8' if utf8 else 'utf-16le'))
    return result


def read_elements(data: bytes) -> list[tuple[str, dict]]:
    require(len(data) >= 8, 'Truncated binary XML')
    kind, header, total = struct.unpack_from('<HHI', data)
    require(kind == 3 and header == 8 and total == len(data), 'Invalid binary XML header')
    strings = None
    result = []

    def text(index: int) -> str | None:
        if index == NO_INDEX:
            return None
        require(strings is not None and 0 <= index < len(strings), 'Invalid string index')
        return strings[index]

    pos = header
    while pos < total:
        require(pos + 8 <= total, 'Truncated chunk header')
        kind, size, length = struct.unpack_from('<HHI', data, pos)
        require(8 <= size <= length and pos + length <= total, 'Invalid chunk bounds')
        chunk = data[pos:pos + length]
        if kind == 1:
            require(strings is None, 'Duplicate string pool')
            strings = _strings(chunk, size)
        elif kind == 0x102:
            require(size >= 16 and size + 20 <= length, 'Truncated XML start element')
            _ns, name, attr_start, attr_size, count, *_ = struct.unpack_from('<II6H', chunk, size)
            require(attr_start >= 20 and attr_size >= 20 and
                    size + attr_start + count * attr_size <= length, 'Invalid attribute bounds')
            attrs = {}
            for i in range(count):
                offset = size + attr_start + i * attr_size
                ns, key, _raw, value_size, zero, value_type, value = struct.unpack_from('<IIIHBBI', chunk, offset)
                require(value_size == 8 and zero == 0, 'Invalid typed value')
                qname = (text(ns), text(key))
                require(qname not in attrs, 'Duplicate attribute')
                attrs[qname] = (value_type, text(value) if value_type == STRING else value)
            result.append((str(text(name)), attrs))
        pos += length
    require(strings is not None and result, 'Manifest has no elements')
    return result


def verify(data: bytes) -> dict:
    elements = read_elements(data)
    roots = [attrs for tag, attrs in elements if tag == 'manifest']
    require(len(roots) == 1, 'Expected one manifest root')
    require(roots[0].get((None, 'package')) == (STRING, 'org.mightyjuke.senjin'),
            'Unexpected package identifier')
    features = {}
    gles = None
    for tag, attrs in elements:
        if tag != 'uses-feature':
            continue
        name = attrs.get((ANDROID, 'name'), (STRING, 'OpenGL ES'))[1]
        required = attrs.get((ANDROID, 'required'))
        version = attrs.get((ANDROID, 'version'))
        if required is not None:
            require(required[0] == BOOLEAN and required[1] in (0, 0xFFFFFFFF),
                    f'{name}: android:required must be a compiled boolean, got {required!r}')
        if version is not None:
            require(version[0] in (INT_DEC, INT_HEX),
                    f'{name}: android:version must be a compiled integer, got {version!r}')
        if (ANDROID, 'glEsVersion') in attrs:
            gles = attrs[(ANDROID, 'glEsVersion')]
        if name in ('android.hardware.vulkan.level', 'android.hardware.vulkan.version'):
            require(name not in features, f'Duplicate {name}')
            require(required == (BOOLEAN, 0), f'{name}: Vulkan must stay optional for Compatibility fallback')
            require(version is not None, f'{name}: version missing')
            features[name] = version[1]
    require(gles is not None and gles[0] in (INT_DEC, INT_HEX) and gles[1] >= 0x30000,
            'OpenGL ES 3 fallback declaration missing')
    require(features == {'android.hardware.vulkan.level': 1, 'android.hardware.vulkan.version': 0x401000},
            f'Unexpected Vulkan feature contract: {features!r}')
    return {'package': 'org.mightyjuke.senjin', 'vulkan_required': False,
            'vulkan_level': features['android.hardware.vulkan.level'],
            'vulkan_version': features['android.hardware.vulkan.version'], 'gles_version': gles[1]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    try:
        with zipfile.ZipFile(args.apk) as apk:
            info = apk.getinfo('AndroidManifest.xml')
            require(info.file_size < 4 * 1024 * 1024, 'Manifest is unexpectedly large')
            result = verify(apk.read(info))
        print('SENJIN_ANDROID_MANIFEST_PASS ' + json.dumps(result, sort_keys=True))
        return 0
    except (OSError, KeyError, ValueError, struct.error, zipfile.BadZipFile) as exc:
        print(f'SENJIN_ANDROID_MANIFEST_FAIL: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
