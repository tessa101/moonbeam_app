# Load-in onsets per block, at real pts. Blocks are found as runs of non-background
# rows in the settled upsell; a block "starts" when its band first brightens by > 1.5.
import subprocess, sys, re
W, H = 201, 437  # half of the 402x874 pt screen, so 1 row = 2 pt
def frames(f):
    pts = [float(m) for m in re.findall(r"pts_time:([\d.]+)", subprocess.run(
        ["ffmpeg","-v","info","-i",f,"-vf","showinfo","-f","null","-"],capture_output=True,text=True).stderr)]
    raw = subprocess.run(["ffmpeg","-v","error","-i",f,"-fps_mode","passthrough","-vf",f"scale={W}:{H}",
        "-pix_fmt","gray","-f","rawvideo","-"],capture_output=True).stdout
    return pts, [raw[i*W*H:(i+1)*W*H] for i in range(len(raw)//(W*H))]
def rowmeans(fr): return [sum(fr[r*W:(r+1)*W])/W for r in range(H)]
f = sys.argv[1]; pts, fs = frames(f)
final = rowmeans(fs[-1]); bg = sorted(final)[H//4]
rows = [r for r in range(H) if final[r] > bg + 3]
blocks=[]; 
for r in rows:
    if blocks and r - blocks[-1][1] <= 6: blocks[-1][1] = r   # merge gaps under 12 pt
    else: blocks.append([r, r])
blocks = [b for b in blocks if b[1]-b[0] >= 3 and b[0] > 30]
# The page swap: the last frame of the landing's fade-out = the darkest frame after the tap.
tap = next(i for i in range(len(fs)) if pts[i] > float(sys.argv[2]))
total = [sum(fr)/len(fr) for fr in fs]
fadeStart = tap
swap = min(range(tap, min(tap+40, len(fs))), key=lambda i: total[i])
print(f"fade-out {pts[fadeStart]:.3f} -> darkest {pts[swap]:.3f} ({pts[swap]-pts[fadeStart]:.3f} s)")
for a,b in blocks:
    base = sum(rowmeans(fs[swap])[a:b+1])/(b-a+1)
    on = next((pts[i] for i in range(swap, len(fs)) if sum(rowmeans(fs[i])[a:b+1])/(b-a+1) > base+1.5), None)
    print(f"block rows {a*2:3d}-{b*2:3d} pt: starts {on - pts[swap] if on else float('nan'):.3f} s after swap")
