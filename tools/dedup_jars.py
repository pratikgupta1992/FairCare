#!/usr/bin/env python3
"""Class-level jar dedup: for classes defined in multiple jars, keep the copy
from the highest-version artifact; emit filtered jars containing everything else.
Usage: dedup_jars.py <cp-file> <out-dir>
Writes <out-dir>/*.jar and prints the new classpath."""
import os, re, sys, zipfile
from collections import defaultdict

cp_file, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)

jars = open(cp_file).read().strip().split(":")

def version_of(path):
    base = os.path.basename(path)
    m = re.search(r"-(\d+(?:\.\d+)*)(?:-rc\d+)?\.(?:jar|aar)$", base)
    if not m:
        return (0,)
    return tuple(int(x) for x in m.group(1).split("."))

def classes_in(jar):
    try:
        with zipfile.ZipFile(jar) as z:
            return [n for n in z.namelist() if n.endswith(".class")]
    except Exception:
        return []

# class -> [(jar, version)]
owners = defaultdict(list)
jar_classes = {}
for j in jars:
    if not os.path.exists(j):
        continue
    cs = classes_in(j)
    jar_classes[j] = cs
    v = version_of(j)
    for c in cs:
        owners[c].append((j, v))

# winner per duplicated class
winner = {}
for c, js in owners.items():
    if len(js) > 1:
        # highest version wins; tie-break prefers -android/-jvm/-ktx suffixed artifacts
        def score(item):
            j, v = item
            suffix_bonus = 1 if re.search(r"-(android|jvm|ktx)-\d", j) else 0
            return (v, suffix_bonus, j)
        winner[c] = max(js, key=score)[0]

new_cp = []
for j in jars:
    if not os.path.exists(j):
        continue
    lost = {c for c in jar_classes.get(j, []) if winner.get(c, j) != j}
    if not lost:
        new_cp.append(j)
        continue
    out = os.path.join(out_dir, os.path.basename(j))
    with zipfile.ZipFile(j) as zin, zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename in lost:
                continue
            zout.writestr(item, zin.read(item.filename))
    new_cp.append(out)
    print(f"deduped {os.path.basename(j)}: dropped {len(lost)} classes", file=sys.stderr)

print(":".join(new_cp))
