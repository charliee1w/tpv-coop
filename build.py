# Packs src/ into TPV_TagAlong_Coop.pk3 (a zip). Run: python build.py
import io, os, zipfile
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "src")
out = os.path.join(here, "TPV_TagAlong_Coop.pk3")
buf = io.BytesIO()
with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, src).replace(os.sep, "/"))
with open(out, "wb") as fo:
    fo.write(buf.getvalue())
print("built", out, os.path.getsize(out), "bytes")
