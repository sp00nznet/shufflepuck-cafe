#!/usr/bin/env python3
"""Shufflepuck Cafe conformance harness (REPO_RULES section 9).

Two fixed corpora, one pass/fail count each, compared against the committed
baseline in conformance.json; a regression fails the run:

* **Boot milestones**: a headless, recorded run of build/shufflepuck, scored by
  the lines the loader and the macrecomp runtime print at each stage. The
  original game is the ground truth: it does each of these on every start.
* **Lift health**: from the generated tree, the instructions the lifter could
  not translate (m68k_unimplemented sites in src/gen). Fewer is better.

The game is not in the repo. Without work/unpacked and the built exe this
skips with a message and exits 0, so it can sit in CI without the corpus.

    py -3 tools/conformance.py              # run, compare, print the table
    py -3 tools/conformance.py --update     # ...and accept the result as the baseline
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXE = os.path.join(ROOT, 'build', 'shufflepuck.exe' if os.name == 'nt' else 'shufflepuck')
DATA = os.path.join(ROOT, 'work', 'unpacked')
GEN = os.path.join(ROOT, 'src', 'gen')
BASELINE = os.path.join(ROOT, 'conformance.json')
SECONDS = 20

# (name, regex over the run's stderr, present=pass). Order is boot order.
MILESTONES = [
    ('resources registered', r'loaded [1-9]\d* resources', True),
    ('game main entered', r'boot: calling game main', True),
    # the data fork open used to fail and raise "Sorry, this disk is full."
    ('no dialog before the event loop', r'\[dlg\]', False),
    ('event loop reached', r'\[boot\] event loop reached', True),
    ('ran to the watchdog without faulting', r'\[watchdog\]', True),
    ('recording finalised', r'\[record\] [1-9]\d* frames', True),
]


def boot():
    os.makedirs(os.path.join(ROOT, 'scratch'), exist_ok=True)
    env = dict(os.environ, MRDLG='1')
    try:
        p = subprocess.run([EXE, '--headless', '--watchdog', str(SECONDS),
                            '--record', os.path.join('scratch', 'conformance.mp4'), DATA],
                           cwd=ROOT, env=env, capture_output=True, text=True,
                           errors='replace', timeout=SECONDS + 60)
        return p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b'') + (e.stderr or b'')
        return out.decode(errors='replace') if isinstance(out, bytes) else out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--update', action='store_true', help='accept this run as the baseline')
    a = ap.parse_args()

    if not (os.path.exists(EXE) and os.path.isdir(DATA)):
        print('conformance: SKIPPED (no build/work: run build.sh with your own disk image first)')
        return 0

    log = boot()
    with open(os.path.join(ROOT, 'scratch', 'conformance.log'), 'w', encoding='utf-8') as f:
        f.write(log)
    passed = 0
    for name, rx, want in MILESTONES:
        ok = bool(re.search(rx, log)) == want
        passed += ok
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    unimpl = sum(open(p, encoding='utf-8', errors='replace').read().count('m68k_unimplemented(')
                 for p in glob.glob(os.path.join(GEN, 'code_*.c')))
    now = {'milestones': passed, 'of': len(MILESTONES), 'unimplemented': unimpl}
    print(f"conformance: {passed}/{len(MILESTONES)} milestones, {unimpl} unimplemented instructions")

    if a.update or not os.path.exists(BASELINE):
        with open(BASELINE, 'w') as f:
            json.dump(now, f, indent=1)
        print(f'baseline written: {BASELINE}')
        return 0
    base = json.load(open(BASELINE))
    bad = []
    if passed < base['milestones']:
        bad.append(f"milestones {passed} < baseline {base['milestones']}")
    if unimpl > base['unimplemented']:
        bad.append(f"unimplemented {unimpl} > baseline {base['unimplemented']}")
    if bad:
        print('REGRESSION: ' + '; '.join(bad) + ' (log: scratch/conformance.log)')
        return 1
    print(f"no regression against the baseline ({base['milestones']}/{base['of']}, {base['unimplemented']})")
    return 0


if __name__ == '__main__':
    sys.exit(main())
