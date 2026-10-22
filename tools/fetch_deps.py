#!/usr/bin/env python3
"""Fetch the full transitive dependency closure as AAR/JAR files via curl (proxy-friendly).

Usage: fetch_deps.py <output-dir>
Writes <output-dir>/artifacts.json + downloads into <output-dir>/files/
"""
import os, re, sys, subprocess, xml.etree.ElementTree as ET

OUT = sys.argv[1]
FILES = os.path.join(OUT, "files")
os.makedirs(FILES, exist_ok=True)

GOOGLE = "https://maven.google.com"
CENTRAL = "https://repo1.maven.org/maven2"

DIRECT = [
    ("org.jetbrains.kotlin", "kotlin-stdlib", "2.0.20"),
    ("org.jetbrains.kotlinx", "kotlinx-coroutines-android", "1.8.1"),
    ("androidx.core", "core-ktx", "1.13.1"),
    ("androidx.activity", "activity-compose", "1.9.2"),
    ("androidx.compose.ui", "ui", "1.6.8"),
    ("androidx.compose.foundation", "foundation", "1.6.8"),
    ("androidx.compose.material3", "material3", "1.2.1"),
    ("androidx.compose.material", "material-icons-core", "1.6.8"),
    ("androidx.compose.material", "material-icons-extended", "1.6.8"),
    ("androidx.compose.material", "material-icons-core-android", "1.6.8"),
    ("androidx.compose.material", "material-icons-extended-android", "1.6.8"),
    ("androidx.compose.runtime", "runtime", "1.6.8"),
    ("androidx.lifecycle", "lifecycle-viewmodel-compose", "2.7.0"),
    ("androidx.lifecycle", "lifecycle-runtime-compose", "2.7.0"),
]

NS = {"m": "http://maven.apache.org/POM/4.0.0"}

def curl(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        # validate cached file isn't a 404 page
        head = open(dest, "rb").read(200)
        if b"Error 404" in head:
            os.remove(dest)
        else:
            return True
    r = subprocess.run(["curl", "-sSL", "--retry", "2", "-o", dest, url],
                       capture_output=True)
    if r.returncode != 0 or not os.path.exists(dest) or os.path.getsize(dest) == 0:
        return False
    head = open(dest, "rb").read(200)
    if b"Error 404" in head:
        os.remove(dest)
        return False
    return True

def base_url(group, artifact, version, repo):
    path = "%s/%s/%s/%s/%s-%s" % (repo, group.replace(".", "/"), artifact, version, artifact, version)
    return path

def fetch_pom(group, artifact, version):
    for repo in (GOOGLE, CENTRAL):
        dest = os.path.join(FILES, f"{group}__{artifact}__{version}.pom")
        if curl(base_url(group, artifact, version, repo) + ".pom", dest):
            return dest
    return None

def parse_pom(pom_path):
    """Return (packaging, properties, deps[(g,a,v,optional,scope)]) with parent props merged."""
    tree = ET.parse(pom_path)
    root = tree.getroot()
    def txt(node, name):
        el = node.find(f"m:{name}", NS)
        return el.text.strip() if el is not None and el.text else None

    packaging = txt(root, "packaging") or "jar"
    props = {}
    for p in root.findall("m:properties", NS):
        for child in p:
            tag = re.sub(r"\{.*\}", "", child.tag)
            props[tag] = child.text.strip() if child.text else ""

    # parent properties (one level is enough for androidx)
    parent = root.find("m:parent", NS)
    if parent is not None:
        pg, pa, pv = txt(parent, "groupId"), txt(parent, "artifactId"), txt(parent, "version")
        if pg and pa and pv:
            pp = fetch_pom(pg, pa, pv)
            if pp:
                _, pprops, _ = parse_pom(pp)
                for k, v in pprops.items():
                    props.setdefault(k, v)

    def resolve(s):
        if not s:
            return s
        def rep(m):
            return props.get(m.group(1), m.group(0))
        return re.sub(r"\$\{([^}]+)\}", rep, s)

    deps = []
    for d in root.findall("m:dependencies/m:dependency", NS):
        g, a, v = txt(d, "groupId"), txt(d, "artifactId"), txt(d, "version")
        scope = txt(d, "scope") or "compile"
        opt = txt(d, "optional") == "true"
        if not g or not a:
            continue
        g, a = resolve(g), resolve(a)
        v = resolve(v) if v else None
        if scope in ("test", "provided") or opt:
            continue
        if v is None or "$" in v:
            continue
        # skip annotation-processor-only and lint artifacts
        if a.endswith("-compiler") or a.endswith("-lint") or "annotation-processor" in a:
            continue
        deps.append((g, a, v))
    return packaging, props, deps

def main():
    resolved = {}  # (g,a) -> (version, packaging, file)
    queue = list(DIRECT)
    seen = set()
    order = []
    while queue:
        g, a, v = queue.pop(0)
        if (g, a) in seen:
            continue
        seen.add((g, a))
        # resolve maven version ranges like "[1.2.1]" to the pinned version
        if v.startswith("[") and v.endswith("]"):
            v = v[1:-1].split(",")[0].strip()
        pom = fetch_pom(g, a, v)
        if pom is None:
            print(f"WARN: no pom for {g}:{a}:{v}", flush=True)
            continue
        packaging, props, deps = parse_pom(pom)
        # download artifact: prefer aar when packaging==aar
        ext = "aar" if packaging == "aar" else "jar"
        fname = f"{a}-{v}.{ext}"
        dest = os.path.join(FILES, fname)
        got = False
        for repo in (GOOGLE, CENTRAL):
            if curl(base_url(g, a, v, repo) + f".{ext}", dest):
                got = True
                break
        if not got and ext == "aar":
            # fall back to jar
            dest = os.path.join(FILES, f"{a}-{v}.jar")
            for repo in (GOOGLE, CENTRAL):
                if curl(base_url(g, a, v, repo) + ".jar", dest):
                    got = True
                    ext = "jar"
                    break
        if not got:
            print(f"WARN: no artifact for {g}:{a}:{v}", flush=True)
            continue
        resolved[(g, a)] = (v, ext, dest)
        order.append((g, a, v, ext, dest))
        print(f"OK {g}:{a}:{v} [{ext}] (+{len(deps)} deps)", flush=True)
        for dg, da, dv in deps:
            if (dg, da) not in seen:
                queue.append((dg, da, dv))

    import json
    with open(os.path.join(OUT, "artifacts.json"), "w") as f:
        json.dump([{"group": g, "artifact": a, "version": v, "packaging": e, "file": d}
                   for g, a, v, e, d in order], f, indent=1)
    print(f"DONE: {len(order)} artifacts")

main()
