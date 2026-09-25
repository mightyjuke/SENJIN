#!/usr/bin/env python3
"""Validate the checked-in glTF kit without Blender or third-party Python packages.
SPDX-License-Identifier: MIT
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

BUDGETS = {"vanguard": 6000, "officer": 6000, "soldier": 4000,
           "soldier_body": 500, "soldier_leg_l": 100, "soldier_leg_r": 100}
DURATIONS = {"n1":35,"n2":35,"n3":30,"n4":38,"n5":50,"n6":48,
             "c1":56,"c2":112,"c3":114,"c4":76,"c5":80,"c6":130,
             "dash":88,"jatk":22,"jc":56,"Surge":200}
EXPECTED = set(BUDGETS) | {"polearm", "wall", "gate", "tower", "barricade", "banner", "tent", "brazier", "crate", "rock", "paver", "slash_arc", "shock_ring", "spark", "surge_ribbon"}

def inspect(path: Path) -> dict:
    raw = path.read_bytes()
    assert struct.unpack_from("<4sII", raw) == (b"glTF", 2, len(raw)), path
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A, path
    data = json.loads(raw[20:20+length])
    assert not any("uri" in b for b in data.get("buffers", [])), f"{path}: external buffer"
    assert not data.get("images"), f"{path}: this vertex-painted kit must not bundle images/fonts"
    assert len(data.get("meshes", [])) == 1, f"{path}: one mesh required"
    assert len(data.get("materials", [])) == 1, f"{path}: one material required"
    triangles = 0
    for mesh in data["meshes"]:
        assert len(mesh["primitives"]) == 1, f"{path}: one primitive required"
        for primitive in mesh["primitives"]:
            assert primitive.get("mode",4) == 4, f"{path}: triangles required"
            assert "COLOR_0" in primitive["attributes"] and "NORMAL" in primitive["attributes"]
            triangles += data["accessors"][primitive["indices"]]["count"] // 3
    assert 0 < triangles <= BUDGETS.get(path.stem,4000), f"{path}: {triangles} over budget"
    clips = {a["name"]: a for a in data.get("animations",[])}
    bones = max([len(s["joints"]) for s in data.get("skins",[])], default=0)
    if path.stem in ("vanguard","soldier","officer"):
        assert bones == 18 and len(clips) == 23, f"{path}: rig/clip contract"
        assert {"TrailBase","TrailTip"}.issubset({n.get("name","") for n in data.get("nodes",[])})
        for clip,frames in DURATIONS.items():
            duration=max(data["accessors"][s["input"]]["max"][0] for s in clips[clip]["samplers"])
            assert abs(duration-frames/60)<0.001, f"{path}: wrong duration for {clip}"
        attrs=data["meshes"][0]["primitives"][0]["attributes"]
        assert "JOINTS_0" in attrs and "WEIGHTS_0" in attrs
    else:
        assert bones==0 and not clips, f"{path}: static mesh unexpectedly animated"
    return {"name":path.stem,"file":path.name,"bytes":len(raw),"triangles":triangles,
            "meshes":1,"materials":1,"bones":bones,"animations":list(clips),
            "sha256":hashlib.sha256(raw).hexdigest()}

def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=Path,default=Path.cwd())
    parser.add_argument("--refresh-manifest",action="store_true",help="After intentionally exporting an edited .blend")
    args=parser.parse_args()
    folder=args.root.resolve()/"godot/assets/models"
    manifest_path=folder/"manifest.json"
    manifest=json.loads(manifest_path.read_text())
    assert {p.stem for p in folder.glob("*.glb")} == EXPECTED, "Asset set is incomplete or contains unmanaged exports"
    assert {e['name'] for e in manifest['assets']} == EXPECTED, 'Incomplete or duplicate manifest'
    assert len(manifest['assets']) == len(EXPECTED), 'Duplicate manifest entries'
    entries=[inspect(folder/e["file"]) for e in manifest["assets"]]
    assert sum(e["bytes"] for e in entries)<8*1024*1024,"GLB pack exceeds 8 MiB"
    for old,new in zip(manifest["assets"],entries):
        if not args.refresh_manifest:
            assert old==new,f"Stale manifest: {new['file']}. Refresh only after an intentional export."
    if args.refresh_manifest:
        manifest["assets"]=entries
        manifest_path.write_text(json.dumps(manifest,indent=2)+"\n")
    print("SENJIN_GLB_CONTRACT_PASS",json.dumps({"assets":len(entries),"bytes":sum(e["bytes"] for e in entries)}))
if __name__=="__main__":
    main()
