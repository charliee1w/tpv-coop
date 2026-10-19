# Builds a release of the co-op add-on: the pk3 (from src/), launcher/version.txt, the share zip and
# manifest.json (every file the launcher keeps up to date, with its SHA-256).
#   python tools/release.py 8                 build only, into tools/release_v8/
#   python tools/release.py 8 --publish       also create GitHub release v8 with those files
#   python tools/release.py 8 --publish --replace   remake release v8 (only before anyone downloaded it)
# The notes for the release page come from tools/notes_v<version>.txt.
import hashlib, json, os, shutil, subprocess, sys, zipfile

REPO = "charliee1w/tpv-coop"
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
version = sys.argv[1]
tag = "v" + version
out = os.path.join(root, "tools", "release_" + tag)

# (path in the TPV co-op folder, release asset name). Asset names can't have spaces or folders.
FILES = [
    ("TPV_TagAlong_Coop.pk3", "TPV_TagAlong_Coop.pk3"),
    ("launcher/tpv-coop.ps1", "tpv-coop.ps1"),
    ("launcher/version.txt", "version.txt"),
    ("Host co-op.bat", "host.bat"),
    ("Join co-op.bat", "join.bat"),
    ("Try it on this PC (two windows).bat", "try.bat"),
    ("README.md", "README.md"),
]

def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest().upper()

# The pk3: every file in src/, fixed timestamps so the same source always gives the same bytes.
pk3 = os.path.join(root, "TPV_TagAlong_Coop.pk3")
with zipfile.ZipFile(pk3, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(os.path.join(root, "src"))):
        with open(os.path.join(root, "src", name), "rb") as f:
            data = f.read()
        info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)

with open(os.path.join(root, "launcher", "version.txt"), "w", newline="") as f:
    f.write(version + "\r\n")

if os.path.isdir(out):
    shutil.rmtree(out)
os.makedirs(out)
manifest = {"version": version, "tag": tag, "files": []}
for path, asset in FILES:
    src = os.path.join(root, path.replace("/", os.sep))
    shutil.copyfile(src, os.path.join(out, asset))
    manifest["files"].append({"path": path, "asset": asset, "sha256": sha(src)})
with open(os.path.join(out, "manifest.json"), "w", newline="") as f:
    json.dump(manifest, f, indent=1)

# The zip for new players (one "TPV co-op" folder).
zpath = os.path.join(root, "TPV co-op (send this to friends).zip")
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
    for path, _ in FILES:
        z.write(os.path.join(root, path.replace("/", os.sep)), "TPV co-op/" + path)
shutil.copyfile(zpath, os.path.join(out, "TPV-co-op.zip"))

for e in manifest["files"]:
    print(e["sha256"][:12], e["path"])
print("zip", os.path.getsize(zpath), "bytes, pk3", os.path.getsize(pk3), "bytes")

if "--publish" in sys.argv:
    notes = os.path.join(root, "tools", "notes_%s.txt" % tag)
    assets = [os.path.join(out, a) for _, a in FILES] + [os.path.join(out, "manifest.json"), os.path.join(out, "TPV-co-op.zip")]
    if "--replace" in sys.argv:
        # Only before anyone has it: drop the release and its tag, then make it again.
        subprocess.run(["gh", "release", "delete", tag, "--repo", REPO, "--yes", "--cleanup-tag"], check=False)
    cmd = ["gh", "release", "create", tag, "--repo", REPO, "--title", "TPV co-op " + tag, "--notes-file", notes] + assets
    subprocess.run(cmd, check=True)
    print("published", tag)
