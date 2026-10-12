#!/usr/bin/env python3
"""Run xcodebuild without a PTY; stop on PTY/CoreSimulator errors or timeout.

Usage: run_xcodebuild_guarded.py --log PATH --timeout 600 -- XCODEBUILD_ARGS
"""
import argparse
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--timeout', type=int, default=600)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('supply xcodebuild arguments after --')
    args.log.parent.mkdir(parents=True, exist_ok=True)
    process = subprocess.Popen(['xcodebuild', *command], stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + args.timeout
    pending = b''
    recent = []
    reason = None
    with args.log.open('wb') as log:
        while selector.get_map():
            if time.monotonic() >= deadline:
                reason = f'time limit ({args.timeout} seconds)'
                break
            for key, _ in selector.select(timeout=0.2):
                chunk = os.read(key.fileobj.fileno(), 65536)
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                log.write(chunk)
                log.flush()
                pending += chunk
                while b'\n' in pending:
                    line, pending = pending.split(b'\n', 1)
                    text = line.decode(errors='replace')
                    recent.append(text)
                    recent = recent[-15:]
                    lower = text.lower()
                    if re.search(r'pseudo[ -]?terminal', lower) or ('coresimulator' in lower and any(word in lower for word in ('error', 'failed', 'unable', 'invalid'))):
                        reason = text
                        break
                    if any(marker in text for marker in ('** ', 'Test run with', '✘', 'error:', 'Testing failed:')):
                        print(text, flush=True)
                if reason:
                    break
            if reason:
                break
    if reason:
        print('STOP: ' + reason, flush=True)
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
        print('\n'.join(recent), flush=True)
        return 2
    code = process.wait(timeout=10)
    print(f'xcodebuild exit {code}; log: {args.log}', flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())
