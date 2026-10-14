"""Frame-diff a 60 fps resample of a simulator recording over one region.

Usage: swapframes.py video.mov y0_pt y1_pt [threshold]
Prints each run of changed frames (an "event") with its first/last frame,
time, length in frames and the largest single-frame change, so a one-frame
cut shows as a 1-frame event and an animation as a long one.
"""
import subprocess, sys, numpy as np
video, y0, y1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
threshold = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
w, h = map(int, subprocess.check_output(
    ['ffprobe', '-v', 'error', '-select_streams', 'v', '-show_entries', 'stream=width,height',
     '-of', 'csv=p=0', video]).decode().strip().split(','))
scale = w / 402.0  # iPhone 17 is 402 pt wide
top, bottom = int(y0 * scale), int(y1 * scale)
cw = w // 2  # downscale for speed
ch = (bottom - top) // 2
raw = subprocess.check_output([
    'ffmpeg', '-v', 'error', '-i', video, '-vf',
    f'fps=60,crop={w}:{bottom - top}:0:{top},scale={cw}:{ch},format=gray',
    '-f', 'rawvideo', '-'])
frames = np.frombuffer(raw, np.uint8).reshape(-1, ch, cw).astype(np.int16)
diffs = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2))
changed = np.where(diffs > threshold)[0] + 1
events, run = [], []
for f in changed:
    if run and f - run[-1] > 2:
        events.append(run); run = []
    run.append(f)
if run: events.append(run)
print(f'{len(frames)} frames at 60 fps; region y {y0}-{y1} pt; threshold {threshold}')
for e in events:
    peak = max(diffs[f - 1] for f in e)
    print(f'frames {e[0]}-{e[-1]} (t {e[0]/60:.3f}-{e[-1]/60:.3f} s): {e[-1]-e[0]+1} frames changed, '
          f'peak {peak:.1f}, changed-frame diffs {[round(float(diffs[f-1]),1) for f in e][:60]}')
