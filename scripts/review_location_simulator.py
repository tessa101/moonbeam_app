#!/usr/bin/env python3
"""Capture deterministic location destinations on an already-booted simulator.

Uses an existing DEBUG build. Never runs tests, boots/erases a device, or retries
failed commands. Any simctl failure stops the review. Animated artwork means
these are visual-review samples, not pixel-identical snapshot assertions.
"""
import argparse
import json
from pathlib import Path
import subprocess
import queue
import signal
import threading
import time

ROUTES = {
    'denied': ('messageDenied', 'locationFailed.denied'),
    'services-off': ('messageServicesOff', 'locationFailed.servicesOff'),
    'restricted': ('messageRestricted', 'locationFailed.restricted'),
    'no-fix': ('messageNoFix', 'locationFailed.noFixAgain'),
}
BUNDLE = 'com.t-alien.moonbeam-app'


def run(*args):
    result = subprocess.run(['xcrun', 'simctl', *args], capture_output=True, text=True, timeout=45)
    output = result.stdout + result.stderr
    if result.returncode or 'pseudo terminal' in output.lower() or 'pseudo-terminal' in output.lower() or ('coresimulator' in output.lower() and any(word in output.lower() for word in ('error', 'failed', 'invalid'))):
        raise SystemExit(f'STOP: simctl {args}\n{output}')
    return output



def record(device, route, output):
    """Record a real simulator stream; monitor errors while it runs."""
    target = output / f'{route.replace(".", "-")}-continuous.mp4'
    process = subprocess.Popen(['xcrun', 'simctl', 'io', device, 'recordVideo',
        '--codec=h264', str(target)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1)
    messages = queue.Queue()
    def read_output():
        for line in process.stdout:
            messages.put(line)
    threading.Thread(target=read_output, daemon=True).start()
    transcript = []
    def check():
        while not messages.empty():
            line = messages.get()
            transcript.append(line)
            print(line.strip(), flush=True)
            lower = line.lower()
            if any(word in lower for word in ('error', 'failed', 'pseudo terminal', 'pseudo-terminal')):
                process.send_signal(signal.SIGINT)
                raise SystemExit('STOP: recording error\n' + ''.join(transcript))
    deadline = time.monotonic() + 10
    while not any('Recording started' in line for line in transcript):
        check()
        if process.poll() is not None or time.monotonic() > deadline:
            process.send_signal(signal.SIGINT) if process.poll() is None else None
            raise SystemExit('STOP: recorder did not start\n' + ''.join(transcript))
        time.sleep(0.1)
    try:
        run('launch', '--terminate-running-process', device, BUNDLE, '-screenState', route)
        deadline = time.monotonic() + 16
        while time.monotonic() < deadline:
            check()
            if process.poll() is not None:
                raise SystemExit('STOP: recorder exited unexpectedly')
            time.sleep(0.1)
    finally:
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
        process.wait(timeout=10)
    check()
    if process.returncode != 0:
        raise SystemExit(f'STOP: recorder exit {process.returncode}\n' + ''.join(transcript))
    print(f'Recorded {target}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True, help='Already-booted simulator UUID')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--appearance', choices=['light', 'dark'], default='dark')
    parser.add_argument('--text-size', default='large')
    parser.add_argument('--launch-only', action='store_true')
    parser.add_argument('--record', choices=['recoveryAha', 'messageNoFix', 'messageDenied'])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    devices = json.loads(run('list', 'devices', 'booted', '--json'))
    if not any(d['udid'] == args.device for group in devices['devices'].values() for d in group):
        raise SystemExit('STOP: requested simulator is not booted')
    if args.record:
        record(args.device, args.record, args.output)
        return
    original_appearance = run('ui', args.device, 'appearance').strip()
    original_size = run('ui', args.device, 'content_size').strip()
    run('ui', args.device, 'appearance', args.appearance)
    run('ui', args.device, 'content_size', args.text_size)
    manifest = []
    for cause, routes in ROUTES.items():
        for entry, route in zip(('launch', 'explicit'), routes):
            if args.launch_only and entry == 'explicit':
                continue
            # --terminate-running-process avoids a failing terminate on an app
            # that is not running, while giving every route a fresh launch.
            run('launch', '--terminate-running-process', args.device, BUNDLE, '-screenState', route)
            time.sleep(4)
            target = args.output / f'{cause}-{entry}-{args.appearance}-{args.text_size}.png'
            run('io', args.device, 'screenshot', str(target))
            manifest.append({'cause': cause, 'entry': entry, 'route': route, 'file': target.name})
            print(f'Captured {target.name}', flush=True)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    # Restore settings after success. On an error, stop immediately; do not
    # issue more simulator commands, including cleanup commands.
    run('ui', args.device, 'appearance', original_appearance)
    run('ui', args.device, 'content_size', original_size)
    print('Capture complete; appearance and text size restored.', flush=True)


if __name__ == '__main__':
    main()
