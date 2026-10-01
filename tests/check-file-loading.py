#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check repeated file reads and nested loads in one MAL process."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def quote(value):
    return json.dumps(str(value), ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csound", default=os.environ.get("CSOUND", "csound"))
    args = parser.parse_args()
    binary = shutil.which(args.csound)
    if binary is None:
        parser.error(f"Csound executable not found: {args.csound}")
    binary = str(Path(binary).resolve())

    with tempfile.TemporaryDirectory(prefix="mal-file-loading-") as temporary:
        directory = Path(temporary)
        fixtures = [
            ("first.txt", "first\nsecond\n"),
            ("empty.txt", ""),
            ('spaces % # \' " λ.txt', "Unicode: λ\nno final newline"),
            ("long.txt", "x" * 17000 + "\nlast\n"),
        ]
        for name, content in fixtures:
            (directory / name).write_text(content, encoding="utf-8")
        paths = " ".join(quote(directory / name) for name, _ in fixtures)
        contents = " ".join(quote(content) for _, content in fixtures)
        first = directory / "first.mal"
        second = directory / "second.mal"
        outer = directory / "outer.mal"
        first.write_text('(swap! visits conj :first)\n', encoding="utf-8")
        second.write_text('(swap! visits conj :second)\n', encoding="utf-8")
        outer.write_text(f'(load-file {quote(first)})\n(load-file {quote(second)})\n',
                         encoding="utf-8")
        source = f"""
(def! check (fn* (label expected actual)
  (if (= expected actual) nil (throw label))))
(def! paths [{paths}])
(def! expected [{contents}])
(check "different files" expected (map slurp paths))
(check "reopen files" expected (map slurp paths))
(check "same file at one call site"
  (list (first expected) (first expected) (first expected))
  (map slurp (list (first paths) (first paths) (first paths))))
(def! visits (atom []))
(load-file {quote(outer)})
(load-file {quote(outer)})
(check "nested and repeated loads" [:first :second :first :second] @visits)
(println "FILE-LOADING-PASS")
"""
        script = directory / "check.mal"
        script.write_text(source, encoding="utf-8")
        try:
            result = subprocess.run(
                [binary, "-n", "-d", "-m128", "--orc", str(ROOT / "src/run.orc"),
                 "--", str(script)],
                cwd=ROOT, capture_output=True, text=True, timeout=30,
            )
        except subprocess.TimeoutExpired:
            print("FAIL: file loading exceeded 30 seconds", file=sys.stderr)
            return 1
        output = result.stdout + result.stderr
        if result.returncode or "FILE-LOADING-PASS" not in output.splitlines():
            print(f"FAIL: file loading\n{output}", file=sys.stderr)
            return 1
    print("PASS: repeated reads, empty files, long lines, filenames, and nested loads")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
