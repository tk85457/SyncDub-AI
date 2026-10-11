"""One-off: convert assets/images/anim_*.gif -> small animated .webp (128px, keeps alpha + timing)."""
import glob, os, sys
from PIL import Image, ImageSequence

SIZE = 128
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "images")
total_in = total_out = 0
for gif in sorted(glob.glob(os.path.join(ROOT, "anim_*.gif"))):
    im = Image.open(gif)
    frames, durations = [], []
    for fr in ImageSequence.Iterator(im):
        f = fr.convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        frames.append(f)
        durations.append(max(20, fr.info.get("duration", 40)))
    out = gif[:-4] + ".webp"
    frames[0].save(out, format="WEBP", save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, quality=75, method=6, lossless=False,
                   minimize_size=True)
    a, b = os.path.getsize(gif), os.path.getsize(out)
    total_in += a; total_out += b
    chk = Image.open(out)
    print(f"{os.path.basename(gif):22s} {a/1024:7.0f}KB -> {b/1024:6.0f}KB  frames {len(frames)}->{getattr(chk,'n_frames',1)}")
print(f"TOTAL {total_in/1024:.0f}KB -> {total_out/1024:.0f}KB")
