#!/usr/bin/env python3
"""Run a Luau script in Roblox Studio headless-ish (--task RunScript) and collect BC_ lines.

Studio prints to stdout; --outputFile is often empty and the process may not exit after a
Play test, so we tail stdout, stop on a done marker or timeout, and kill ONLY our own PID.
Usage: run_studio.py PLACE.rbxlx SCRIPT.luau [--timeout 120] [--log out.log] [--quiet]
"""
import argparse, os, re, signal, subprocess, sys, threading, time

STUDIO = os.environ.get('BC_STUDIO', '/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio')
THROTTLE = 'Pushing throttle render state'
# Real script output only. Studio also echoes the script source (lines starting "> " or unprefixed),
# so a bare substring match on "BC_" would read source text as results.
# Runtime/compile errors arrive on a separate channel ([FLog::CreatorError]); their stack lines come back on
# CreatorOutput as "Info: Script '...', Line N". Both must surface or a crash reads as "no output".
OUT = re.compile(r',(Info|Warning|Error) \[FLog::Creator(Output|Error)\] (?!> )(.*)$')


# Engine asset-fetch noise, not our code (we load no animations): Roblox's default avatar Animate
# script sometimes can't fetch its animations in an unpublished Studio place. Shown as BC_WARN, not a failure.
ENGINE_NOISE = ('Failed to load animation with sanitized ID', 'Animation failed to load, assetId: https://assetdelivery')


def parse(line):
    m = OUT.search(line)
    if not m:
        return None
    level, chan, msg = m.groups()
    if msg.startswith('BC_'):
        return msg
    if any(n in msg for n in ENGINE_NOISE):
        return 'BC_WARN engine asset noise: ' + msg[:120]
    if chan == 'Error' or level == 'Error':
        return 'BC_ERR ' + msg
    if msg.startswith("Info: Script '"):
        return 'BC_ERR   at ' + msg[6:]
    return None


def run(place, script, timeout=120, log=None, quiet=False):
    place, script = os.path.abspath(place), os.path.abspath(script)
    log = os.path.abspath(log or os.path.splitext(script)[0] + '.log')
    outfile = log[:-4] + '.studio.log' if log.endswith('.log') else log + '.studio.log'  # Studio rejects non-.log names
    for p in (log, outfile):
        if os.path.exists(p):
            os.remove(p)
    cmd = [STUDIO, '--task', 'RunScript', '--localPlaceFile', place, '--runScriptFile', script,
           '--outputFile', outfile, '--quitAfterExecution']
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                            errors='replace', start_new_session=True)
    lines, state = [], {'done': False, 'throttled': False}

    def reader():
        with open(log, 'w') as fh:
            for line in proc.stdout:
                fh.write(line); fh.flush()
                if THROTTLE in line:
                    state['throttled'] = True
                msg = parse(line)
                if msg:
                    lines.append(msg)
                    if msg.startswith(('BC_DONE', 'BC_FATAL')):
                        state['done'] = True

    t = threading.Thread(target=reader, daemon=True); t.start()
    start = time.time()
    while time.time() - start < timeout and proc.poll() is None and not state['done']:
        time.sleep(0.25)
    timed_out = not state['done'] and proc.poll() is None
    time.sleep(0.5)  # let trailing lines flush
    if proc.poll() is None:  # exact PID only (own session group), never a pattern kill
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        for _ in range(20):
            if proc.poll() is not None:
                break
            time.sleep(0.25)
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGKILL)
    t.join(timeout=2)
    if os.path.exists(outfile):  # --outputFile is usually never created; merge if it is
        with open(outfile, errors='replace') as fh:
            lines += [m for m in map(parse, fh) if m and m not in lines]
    bc = lines
    if not quiet:
        for l in bc:
            print(l)
        if timed_out:
            print(f'BC_HARNESS TIMEOUT after {timeout}s (pid {proc.pid}); log: {log}')
        if state['throttled']:
            print('BC_HARNESS render throttled: fps from this run is INVALID')
        if not bc:
            print(f'BC_HARNESS no BC_ output (script syntax error?) log: {log}')
    return {'lines': bc, 'timed_out': timed_out, 'throttled': state['throttled'], 'log': log}


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('place'); ap.add_argument('script')
    ap.add_argument('--timeout', type=float, default=120)
    ap.add_argument('--log'); ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args()
    r = run(a.place, a.script, a.timeout, a.log, a.quiet)
    sys.exit(1 if r['timed_out'] or not r['lines'] or any('FAIL' in l or 'FATAL' in l for l in r['lines']) else 0)
