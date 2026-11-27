#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, you can obtain one at https://mozilla.org/MPL/2.0/.

"""Check a terminal readline response and EOF through the real REPL."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main(binary):
    source = """(readline "first> ")
:q
(ns example)
(defn readline [prompt] (str prompt "custom"))
(readline "local-")
(+ 1 2)
(ns user)
(readline "last> ")
"""
    expected = ['":q"', 'nil', '"local-custom"', '3', 'nil', 'nil']
    result = subprocess.run(
        [binary, "-d", "-m0", "-odac", "-+rtaudio=null", "--orc", "src/repl.orc"],
        cwd=ROOT, input=source, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, timeout=30,
    )
    values = [line for line in result.stdout.splitlines() if line in expected]
    if result.returncode != 0 or values != expected:
        print(result.stdout, end="", file=sys.stderr)
        raise SystemExit(f"Expected REPL results {expected}, got {values}")
    print("PASS: terminal readline handles input, namespace shadowing, and EOF")


if __name__ == "__main__":
    main(sys.argv[1])
