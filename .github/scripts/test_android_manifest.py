"""Focused fixtures for the compiled-manifest regression (no SDK required)."""
import struct
import unittest

from verify_android_manifest import ANDROID, BOOLEAN, INT_DEC, INT_HEX, NO_INDEX, STRING, verify


def fixture(*, required=(BOOLEAN, 0), version=(INT_HEX, 0x401000),
            package='org.mightyjuke.senjin', omit='', duplicate=False, utf16=False):
    elements = [
        ('manifest', [(None, 'package', STRING, package)]),
        ('uses-feature', [(ANDROID, 'glEsVersion', INT_HEX, 0x30000),
                          (ANDROID, 'required', BOOLEAN, 0xFFFFFFFF)]),
        ('uses-feature', [(ANDROID, 'name', STRING, 'android.hardware.vulkan.level'),
                          (ANDROID, 'required', *required), (ANDROID, 'version', INT_DEC, 1)]),
        ('uses-feature', [(ANDROID, 'name', STRING, 'android.hardware.vulkan.version'),
                          (ANDROID, 'required', *required), (ANDROID, 'version', *version)]),
    ]
    if omit == 'gles':
        elements.pop(1)
    elif omit == 'feature':
        elements.pop()
    elif omit == 'version':
        elements[-1][1].pop()
    if duplicate:
        elements.append(elements[-1])
    strings = sorted({s for tag, attrs in elements for s in
                      [tag] + [s for ns, key, typ, value in attrs
                               for s in (ns, key, value if typ == STRING else None)] if s is not None})
    index = {s: i for i, s in enumerate(strings)}
    payload, offsets = b'', []
    for s in strings:
        offsets.append(len(payload))
        if utf16:
            encoded = s.encode('utf-16le')
            payload += struct.pack('<H', len(encoded) // 2) + encoded + b'\0\0'
        else:
            encoded = s.encode()
            payload += bytes([len(s), len(encoded)]) + encoded + b'\0'
    payload += b'\0' * (-len(payload) % 4)
    start = 28 + 4 * len(strings)
    pool = struct.pack('<HH6I', 1, 28, start + len(payload), len(strings), 0,
                       0 if utf16 else 0x100, start, 0)
    pool += b''.join(struct.pack('<I', off) for off in offsets) + payload
    chunks = pool
    for tag, attrs in elements:
        values = b''.join(struct.pack('<IIIHBBI', index.get(ns, NO_INDEX), index[key],
                                     NO_INDEX, 8, 0, typ, index[value] if typ == STRING else value)
                          for ns, key, typ, value in attrs)
        chunks += struct.pack('<HH3I', 0x102, 16, 36 + len(values), 1, NO_INDEX)
        chunks += struct.pack('<II6H', NO_INDEX, index[tag], 20, 20, len(attrs), 0, 0, 0) + values
    return struct.pack('<HHI', 3, 8, 8 + len(chunks)) + chunks


class ManifestTests(unittest.TestCase):
    def test_compiled_optional_vulkan(self):
        self.assertFalse(verify(fixture())['vulkan_required'])

    def test_utf16_string_pool(self):
        self.assertEqual(verify(fixture(utf16=True))['vulkan_version'], 0x401000)

    def test_reject_exporter_string_boolean(self):
        with self.assertRaisesRegex(ValueError, 'compiled boolean'):
            verify(fixture(required=(STRING, 'false')))

    def test_reject_string_version(self):
        with self.assertRaisesRegex(ValueError, 'compiled integer'):
            verify(fixture(version=(STRING, '0x401000')))

    def test_reject_integer_as_boolean(self):
        with self.assertRaisesRegex(ValueError, 'compiled boolean'):
            verify(fixture(required=(INT_DEC, 0)))

    def test_reject_required_vulkan(self):
        with self.assertRaisesRegex(ValueError, 'must stay optional'):
            verify(fixture(required=(BOOLEAN, 0xFFFFFFFF)))

    def test_reject_missing_version(self):
        with self.assertRaisesRegex(ValueError, 'version missing'):
            verify(fixture(omit='version'))

    def test_reject_missing_vulkan_feature(self):
        with self.assertRaisesRegex(ValueError, 'feature contract'):
            verify(fixture(omit='feature'))

    def test_reject_missing_fallback(self):
        with self.assertRaisesRegex(ValueError, 'fallback declaration'):
            verify(fixture(omit='gles'))

    def test_reject_duplicate_feature(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            verify(fixture(duplicate=True))

    def test_reject_wrong_package(self):
        with self.assertRaisesRegex(ValueError, 'package identifier'):
            verify(fixture(package='org.example.wrong'))

    def test_reject_truncated_binary(self):
        with self.assertRaises(ValueError):
            verify(fixture()[:-1])


if __name__ == '__main__':
    unittest.main()
