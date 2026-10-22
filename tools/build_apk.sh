#!/bin/bash
# Manual APK build pipeline (no Gradle — the sandbox intercepts localhost TCP,
# which breaks the Gradle daemon protocol). Uses aapt2/d8/apksigner directly.
set -e
export JAVA_HOME=~/workspace/jdk-17
export PATH=$JAVA_HOME/bin:$PATH
cd ~/workspace/faircare

ROOT=~/workspace/faircare
SDK=~/workspace/android-sdk
KOTLINC=~/workspace/kotlinc-1.9
BT=$SDK/build-tools/34.0.0
AAPT=$BT/aapt2
D8="$BT/d8"
APKSIGNER=$BT/apksigner
ZIPALIGN=$BT/zipalign
ANDROID_JAR=$SDK/platforms/android-34/android.jar
WORK=$ROOT/build-manual
DEPS_JSON=$ROOT/deps/artifacts.json
COMPOSE_PLUGIN=$ROOT/deps/plugins/compose-compiler-1.5.14.jar

echo "== 0. filtering multiplatform duplicates =="
mkdir -p $WORK
python3 - "$DEPS_JSON" "$WORK/artifacts-filtered.json" <<'EOF'
import json, sys
arts = json.load(open(sys.argv[1]))
names = {(a['group'], a['artifact']) for a in arts}
def shadowed(a):
    g, n = a['group'], a['artifact']
    # multiplatform -android variant wins over the root artifact;
    # -jvm variant wins over the plain one (e.g. annotation vs annotation-jvm)
    return (g, n + '-android') in names or (g, n + '-jvm') in names
filtered = [a for a in arts if not shadowed(a)]
json.dump(filtered, open(sys.argv[2], "w"), indent=1)
print(f"filtered {len(arts)} -> {len(filtered)} artifacts", file=sys.stderr)
EOF
DEPS_JSON=$WORK/artifacts-filtered.json

echo "== 1. unpacking AARs =="
mkdir -p $WORK/aar
python3 - "$DEPS_JSON" "$WORK/aar" <<'EOF'
import json, sys, os, zipfile
arts = json.load(open(sys.argv[1]))
out = sys.argv[2]
for a in arts:
    if a["packaging"] != "aar":
        continue
    d = os.path.join(out, f"{a['artifact']}-{a['version']}")
    if os.path.exists(os.path.join(d, "classes.jar")):
        continue
    os.makedirs(d, exist_ok=True)
    with zipfile.ZipFile(a["file"]) as z:
        z.extractall(d)
print("unpacked AARs")
EOF

echo "== 2. aapt2 compile (app + libs) =="
mkdir -p $WORK/compiled/app $WORK/libs $WORK/gen
$AAPT compile --dir $ROOT/app/src/main/res -o $WORK/compiled/app/ 2>&1 | head -5 || true
python3 - "$DEPS_JSON" "$WORK" "$AAPT" <<'EOF'
import json, sys, os, subprocess, glob
arts = json.load(open(sys.argv[1]))
work, aapt = sys.argv[2], sys.argv[3]
for a in arts:
    if a["packaging"] != "aar":
        continue
    name = f"{a['artifact']}-{a['version']}"
    resdir = os.path.join(work, "aar", name, "res")
    outdir = os.path.join(work, "compiled", name)
    if not os.path.isdir(resdir):
        continue
    if glob.glob(os.path.join(outdir, "*.flat")):
        continue
    os.makedirs(outdir, exist_ok=True)
    r = subprocess.run([aapt, "compile", "--dir", resdir, "-o", outdir + "/"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"COMPILE FAIL {name}: {r.stderr[:300]}")
        sys.exit(1)
print("compiled lib resources")
EOF

echo "== 3. aapt2 link: single merged table (app + all libs) =="
# All resources go into one table; --auto-add-overlay lets app resources win
# on name conflicts (same as AGP's merge). Library R classes are generated
# afterwards from the final R.txt (step 3b), so IDs always match.
FLATS=$(ls $WORK/compiled/*/*.flat | grep -v "/app/" | sort)
APP_FLATS=$(ls $WORK/compiled/app/*.flat | sort)
$AAPT link -o $WORK/app-base.apk \
    --manifest $ROOT/app/src/main/AndroidManifest.xml \
    -I $ANDROID_JAR \
    --min-sdk-version 26 --target-sdk-version 34 \
    --auto-add-overlay \
    --java $WORK/gen \
    --output-text-symbols $WORK/R.txt \
    $FLATS $APP_FLATS || { echo "APP LINK FAIL"; exit 1; }
echo "linked: $(wc -l < $WORK/R.txt) symbols"

echo "== 3b. generate per-library R.java from final R.txt =="
python3 - "$WORK" "$DEPS_JSON" <<'EOF'
import json, sys, os, re
work, deps_json = sys.argv[1], sys.argv[2]
arts = json.load(open(deps_json))

# Parse final merged R.txt
final_ids = {}          # (type, name) -> hex id
final_arr = {}          # styleable name -> [hex ids]
final_idx = {}          # (styleable, attr_entry) -> index
cur = None
for line in open(os.path.join(work, "R.txt")):
    line = line.strip()
    m = re.match(r"int\[\] styleable (\w+) \{ ([^}]*) \}", line)
    if m:
        n, ids = m.groups()
        final_arr[n] = [x.strip() for x in ids.split(",") if x.strip()]
        cur = n
        continue
    if line == "};":
        cur = None
        continue
    m = re.match(r"int (\w+) (\w+) (\S+)", line)
    if m:
        t, n, v = m.groups()
        if cur is not None and t == "styleable":
            final_idx[(cur, n)] = v
        else:
            final_ids[(t, n)] = v

def pkg_of_aar(a):
    mpath = os.path.join(work, "aar", f"{a['artifact']}-{a['version']}", "AndroidManifest.xml")
    data = open(mpath, encoding="utf-8", errors="replace").read()
    m = re.search(r'package="([^"]+)"', data)
    return m.group(1) if m else None

missing = 0
nlibs = 0
for a in arts:
    if a["packaging"] != "aar":
        continue
    name = f"{a['artifact']}-{a['version']}"
    rtxt = os.path.join(work, "aar", name, "R.txt")
    if not os.path.exists(rtxt):
        continue
    pkg = pkg_of_aar(a)
    if not pkg:
        print(f"WARN: no package for {name}")
        continue
    # collect this lib's symbols grouped by type
    by_type = {}
    arr_ids = {}
    arr_idx = {}
    cur = None
    for line in open(rtxt):
        line = line.strip()
        m = re.match(r"int\[\] styleable (\w+) \{", line)
        if m:
            cur = m.group(1)
            arr_ids[cur] = final_arr.get(cur, [])
            continue
        if line == "};":
            cur = None
            continue
        m = re.match(r"int (\w+) (\w+) (\S+)", line)
        if m:
            t, n, v = m.groups()
            if cur is not None and t == "styleable":
                arr_idx.setdefault(cur, []).append((n, final_idx.get((cur, n), v)))
            else:
                fid = final_ids.get((t, n))
                if fid is None:
                    missing += 1
                    fid = "0x0"
                by_type.setdefault(t, []).append((n, fid))
    outdir = os.path.join(work, "gen", *pkg.split("."))
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "R.java"), "w") as out:
        out.write(f"package {pkg};\npublic final class R {{\n")
        for t in sorted(by_type):
            out.write(f"  public static final class {t} {{\n")
            for n, v in by_type[t]:
                out.write(f"    public static final int {n}={v};\n")
            out.write("  }\n")
        if arr_ids:
            out.write("  public static final class styleable {\n")
            for sname, ids in arr_ids.items():
                out.write(f"    public static final int[] {sname}={{{','.join(ids)}}};\n")
                for aname, idx in arr_idx.get(sname, []):
                    out.write(f"    public static final int {aname}={idx};\n")
            out.write("  }\n")
        out.write("}\n")
    nlibs += 1
print(f"generated R.java for {nlibs} libraries, missing symbols: {missing}")
EOF
echo "R.java generation done"

echo "== 4. compile R.java =="
find $WORK/gen -name "R.java" > $WORK/rjava.list
wc -l $WORK/rjava.list
mkdir -p $WORK/r-classes
javac -nowarn -cp $ANDROID_JAR -d $WORK/r-classes @$WORK/rjava.list

echo "== 5. kotlinc (embeddable 1.9.24 + compose plugin 1.5.14) =="
mkdir -p $WORK/app-classes
find $ROOT/app/src/main/java -name "*.kt" > $WORK/ksrc.list
wc -l $WORK/ksrc.list
CP=$(python3 - "$DEPS_JSON" "$WORK/aar" <<'EOF'
import json, sys, os
arts = json.load(open(sys.argv[1]))
aardir = sys.argv[2]
cp = []
for a in arts:
    if a["packaging"] == "aar":
        j = os.path.join(aardir, f"{a['artifact']}-{a['version']}", "classes.jar")
        if os.path.exists(j):
            cp.append(j)
    else:
        cp.append(a["file"])
print(":".join(cp))
EOF
)
echo "$CP" > $WORK/cp.txt
STDLIB_JAR=$(ls $ROOT/deps/files/kotlin-stdlib-2.0.20.jar)
ANNOT_JAR=$(ls $ROOT/deps/files/annotations-13.0.jar)
TROVE_JAR=$HOME/workspace/kotlinc-1.9/lib/trove4j.jar
java -Xmx384m -cp $HOME/workspace/kotlin-embed/embeddable.jar:$STDLIB_JAR:$ANNOT_JAR:$TROVE_JAR \
    org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
    -no-stdlib \
    -Xplugin=$COMPOSE_PLUGIN \
    -cp "$ANDROID_JAR:$CP:$WORK/r-classes" \
    -d $WORK/app-classes \
    @$WORK/ksrc.list > $WORK/kotlinc.log 2>&1
KOTLIN_EXIT=$?
grep -v "^warning:" $WORK/kotlinc.log | head -30
[ $KOTLIN_EXIT -eq 0 ] || { echo "KOTLINC FAILED (exit $KOTLIN_EXIT)"; exit 1; }
echo "kotlinc done: $(find $WORK/app-classes -name '*.class' | wc -l) classes"

echo "== 6. d8 (dex) =="
mkdir -p $WORK/dex
# jar up class dirs first (this d8 only takes jar/zip inputs)
jar --create --file $WORK/app.jar -C $WORK/app-classes . > /dev/null
jar --create --file $WORK/r.jar -C $WORK/r-classes . > /dev/null
export JAVA_OPTS="-Xmx384m"
DEXCP=$(tr ':' ' ' < $WORK/cp.txt)
# class-level dedup across all jars (multiplatform root/-android/-jvm/-ktx overlaps)
DEDUP_CP=$(python3 $ROOT/tools/dedup_jars.py $WORK/cp.txt $WORK/dedup-jars 2>$WORK/dedup.log)
cat $WORK/dedup.log
DEXCP=$(echo "$DEDUP_CP" | tr ':' ' ')
set -o pipefail
$D8 --min-api 26 --lib $ANDROID_JAR \
    --output $WORK/dex \
    $WORK/app.jar $WORK/r.jar $DEXCP 2>&1 | head -10
set +o pipefail
[ -f $WORK/dex/classes.dex ] || { echo "D8 FAILED: no classes.dex"; exit 1; }
ls $WORK/dex/

echo "== 7. assemble, zipalign, sign =="
# META-INF/services/* (e.g. coroutines MainDispatcherFactory) are NOT carried
# into the dex by d8, but ServiceLoader needs them in the APK at runtime.
rm -rf $WORK/services && mkdir -p $WORK/services
python3 - "$WORK/cp.txt" "$WORK/services" <<'EOF'
import os, sys, zipfile
out = sys.argv[2]
seen = {}
for line in open(sys.argv[1]).read().strip().split(":"):
    if not os.path.exists(line): continue
    try:
        z = zipfile.ZipFile(line)
    except Exception:
        continue
    for n in z.namelist():
        if n.startswith("META-INF/services/") and not n.endswith("/"):
            # first jar wins (same policy as before)
            if n not in seen:
                seen[n] = True
                dest = os.path.join(out, n)
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                open(dest, "wb").write(z.read(n))
print(f"services files: {sorted(seen)}")
EOF
cp $WORK/app-base.apk $WORK/app-unsigned.apk
cd $WORK/dex && zip -q -j $WORK/app-unsigned.apk classes.dex classes2.dex && cd $WORK
# add META-INF/services/* into the APK (before zipalign+sign)
cd $WORK/services && zip -q -r $WORK/app-unsigned.apk META-INF && cd $WORK
if [ ! -f $WORK/debug.keystore ]; then
    keytool -genkeypair -keystore $WORK/debug.keystore -storepass android \
        -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
        -validity 10950 -dname "CN=Android Debug,O=Android,C=US" > /dev/null 2>&1
fi
$ZIPALIGN -f 4 $WORK/app-unsigned.apk $WORK/app-aligned.apk
$APKSIGNER sign --ks $WORK/debug.keystore --ks-pass pass:android \
    --key-pass pass:android --out $WORK/FairCare.apk $WORK/app-aligned.apk
$APKSIGNER verify --print-certs $WORK/FairCare.apk | head -3
ls -la $WORK/FairCare.apk
echo "BUILD OK: $WORK/FairCare.apk"
