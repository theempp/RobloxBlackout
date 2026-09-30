#!/usr/bin/env python3
"""Build each test place and run its suites in one Studio Play session per place; print summaries only.
Studio CLI tests one place per run, so lobby and heist are separate runs; `multi` = heist with 2 clients.
Usage: tools/test.py [--only lobby,heist,multi] [--timeout 240]   (exit 0 only if every check passed)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build, run_studio

ROOT = build.ROOT
SUITES = [  # name, project, place, entry script
    ('lobby', 'test.project.json', 'build/test.rbxlx', 'tools/run_tests.luau'),
    ('heist', 'test-heist.project.json', 'build/test-heist.rbxlx', 'tools/run_tests.luau'),
    ('multi', 'test-heist.project.json', 'build/test-heist.rbxlx', 'tools/run_multi.luau'),
]
timeout = float(sys.argv[sys.argv.index('--timeout') + 1]) if '--timeout' in sys.argv else 240
only = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else [s[0] for s in SUITES]
keep = ('BC_SUITE', 'BC_FAIL', 'BC_TOTAL', 'BC_PERF', 'BC_ERR', 'BC_FATAL', 'BC_WARN')
passed = total = 0
ok = True
built = set()
for name, project, out, entry in SUITES:
    if name not in only or not os.path.exists(os.path.join(ROOT, entry)):
        continue
    if out not in built:
        build.build(project, out)
        built.add(out)
    r = run_studio.run(os.path.join(ROOT, out), os.path.join(ROOT, entry), timeout,
                       os.path.join(ROOT, f'build/test-{name}.log'), quiet=True)
    for line in r['lines']:
        if line.startswith(keep):
            print(f'[{name}] {line}')
    if r['timed_out']:
        print(f'[{name}] BC_HARNESS timeout after {timeout}s; log: build/test-{name}.log')
    if r['throttled']:
        print(f'[{name}] BC_HARNESS render throttled: fps numbers are INVALID (unfocused window)')
    tot = [l for l in r['lines'] if l.startswith('BC_TOTAL')]
    if not tot:
        print(f'[{name}] BC_HARNESS no BC_TOTAL: runner never finished (compile error?) log: build/test-{name}.log')
    else:
        p, t = tot[-1].split()[-1].split('/')
        passed += int(p)
        total += int(t)
    ok = ok and bool(tot) and not r['timed_out'] and not any(l.startswith(('BC_FAIL', 'BC_FATAL', 'BC_ERR')) for l in r['lines'])
print(f'BC_GRAND {passed}/{total}')
sys.exit(0 if ok else 1)
