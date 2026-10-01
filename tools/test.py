#!/usr/bin/env python3
"""Build each test place and run its suites in one Studio Play session per place; print summaries only.
Studio CLI tests one place per run, so lobby and heist are separate runs; `multi` = heist with 2 clients.
Usage: tools/test.py [--only lobby,heist,multi] [--spec Kart,Suspension] [--timeout 240]   (exit 0 only if every check passed)"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build, run_studio

ROOT = build.ROOT
SUITES = [  # name, project, place, entry script
    ('lobby', 'test.project.json', 'build/test.rbxlx', 'tools/run_tests.luau'),
    ('heist', 'test-heist.project.json', 'build/test-heist.rbxlx', 'tools/run_tests.luau'),
    ('multi', 'test-heist.project.json', 'build/test-heist.rbxlx', 'tools/run_multi.luau'),
]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--only', default='lobby,heist,multi')
parser.add_argument('--spec')
parser.add_argument('--timeout', type=float, default=240)
args = parser.parse_args()
timeout, only, spec = args.timeout, args.only.split(','), args.spec
if timeout <= 0 or not only or set(only) - {s[0] for s in SUITES}:
    parser.error('use valid suites (lobby,heist,multi) and a positive timeout')
if spec:
    if 'multi' in only:
        parser.error('--spec requires --only lobby and/or heist')
    available = set()
    for suite in only:
        directory = 'tests/server/specs' if suite == 'lobby' else 'tests/heist/specs'
        available.update(f.removesuffix('.spec.luau') if hasattr(f, 'removesuffix') else f[:-10]
                         for f in os.listdir(os.path.join(ROOT, directory)) if f.endswith('.spec.luau'))
    missing = set(spec.split(',')) - available
    if missing:
        parser.error('unknown specs: ' + ', '.join(sorted(missing)))
keep = ('BC_SUITE', 'BC_SUSP', 'BC_FAIL', 'BC_TOTAL', 'BC_PERF', 'BC_ERR', 'BC_FATAL', 'BC_WARN')
passed = total = 0
ok = True
built = set()
for name, project, out, entry in SUITES:
    if name not in only or not os.path.exists(os.path.join(ROOT, entry)):
        continue
    if out not in built:
        if spec:  # same place + BCTests.Only = the spec filter
            with open(os.path.join(ROOT, project)) as fh:
                pj = json.load(fh)
            test_tree = pj['tree']['ServerScriptService']['BCTests']
            if '$path' in test_tree:
                path = test_tree.pop('$path')
                test_tree.update({
                    'Runner': {'$path': path + '/Runner.server.luau'},
                    'specs': {'$path': path + '/specs'},
                })
            test_tree['Only'] = {'$className': 'StringValue', '$properties': {'Value': spec}}
            project = 'build/_spec.' + project
            with open(os.path.join(ROOT, project), 'w') as fh:
                json.dump(pj, fh)
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
    ok = ok and bool(tot) and (not tot or int(t) > 0 and int(p) == int(t)) and not r['timed_out'] and not any(l.startswith(('BC_FAIL', 'BC_FATAL', 'BC_ERR')) for l in r['lines'])
print(f'BC_GRAND {passed}/{total}')
sys.exit(0 if ok else 1)
