"""Per captured frame (no resample): mean brightness of named regions, in pt on a 402x874 frame.
Usage: regionprobe.py video.mov t0 t1"""
import subprocess, sys, numpy as np
v, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
ts = [float(x.strip(',')) for x in subprocess.check_output(['ffprobe','-v','error','-select_streams','v','-show_entries','frame=pts_time','-of','csv=p=0',v]).decode().split()]
raw = subprocess.check_output(['ffmpeg','-v','quiet','-i',v,'-fps_mode','passthrough','-enc_time_base','1/600','-vf','scale=402:874,format=gray','-f','rawvideo','-'])
f = np.frombuffer(raw, np.uint8).reshape(-1, 874, 402).astype(float)
regions = {'dial': (560, 640, 120, 280), 'prompt': (620, 720, 60, 340), 'note': (790, 820, 30, 370)}
print(len(ts), len(f), file=sys.stderr)
for t, fr in zip(ts, f):
    if t0 <= t <= t1:
        print('%.3f ' % t + '  '.join('%s %.1f' % (k, fr[a:b, c:d].mean()) for k, (a, b, c, d) in regions.items()))
