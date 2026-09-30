#!/usr/bin/env python3
"""Build the test place, run every suite in one Studio Play session, print summaries only.
Usage: tools/test.py [--timeout 180]   (exit 0 only if every check passed)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build, run_studio

ROOT = build.ROOT
timeout = float(sys.argv[sys.argv.index('--timeout') + 1]) if '--timeout' in sys.argv else 180
place = build.build('test.project.json', 'build/test.rbxlx')
r = run_studio.run(place, os.path.join(ROOT, 'tools/run_tests.luau'), timeout,
                   os.path.join(ROOT, 'build/test.log'), quiet=True)
keep = ('BC_SUITE', 'BC_FAIL', 'BC_TOTAL', 'BC_PERF', 'BC_ERR', 'BC_FATAL', 'BC_WARN')
for line in r['lines']:
    if line.startswith(keep):
        print(line)
if r['timed_out']:
    print(f'BC_HARNESS timeout after {timeout}s; log: build/test.log')
if r['throttled']:
    print('BC_HARNESS render throttled: fps numbers are INVALID (unfocused window)')
total = [l for l in r['lines'] if l.startswith('BC_TOTAL')]
ok = bool(total) and not r['timed_out'] and not any(l.startswith(('BC_FAIL', 'BC_FATAL', 'BC_ERR')) for l in r['lines'])
if not total:
    print('BC_HARNESS no BC_TOTAL: runner never finished (compile error?) log: build/test.log')
sys.exit(0 if ok else 1)
