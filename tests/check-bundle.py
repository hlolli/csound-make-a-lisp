#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Build and exercise the include file without access to the source tree."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("bundle", ROOT / "tools/bundle.py")
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class IncludeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mal-bundle-includes-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "src").mkdir()

    def write(self, name, text):
        source = self.root / name
        source.write_text(text, encoding="utf-8")
        return source

    def test_nested_includes_preserve_strings_and_comments(self):
        literals = ('Stext init "escaped \\\" quote; // /* text */"\n'
                    'Sblock init {{\n#include "not-a-file.orc"\n}}\n'
                    '/*\n#include "not-a-file.orc"\n*/\n'
                    '; #include "not-a-file.orc"\n'
                    '// #include "not-a-file.orc"\n')
        main = self.write("src/main.orc", '#include "src/child.orc"\n' + literals)
        self.write("src/child.orc", '#include "leaf.orc" ; local include\n')
        self.write("src/leaf.orc", 'Sleaf init "λ"\n')
        result = bundle.Bundler(self.root).expand(main)
        self.assertIn('Sleaf init "λ"', result)
        self.assertIn(literals, result)
        self.assertNotIn('#include "src/child.orc"', result)
        self.assertNotIn('#include "leaf.orc"', result)

    def test_include_cycle_reports_the_files(self):
        main = self.write("src/main.orc", '#include "child.orc"\n')
        self.write("src/child.orc", '#include "main.orc"\n')
        with self.assertRaisesRegex(ValueError, "src/main.orc -> src/child.orc -> src/main.orc"):
            bundle.Bundler(self.root).expand(main)

    def test_missing_include_reports_the_file(self):
        main = self.write("src/main.orc", '#include "missing.orc"\n')
        with self.assertRaisesRegex(ValueError, "Missing include in src/main.orc: missing.orc"):
            bundle.Bundler(self.root).expand(main)


def run(command, directory, marker=None):
    env = dict(os.environ)
    env.pop("INCDIR", None)
    result = subprocess.run(command, cwd=directory, env=env, capture_output=True,
                            text=True, timeout=120)
    output = result.stdout + result.stderr
    if result.returncode or (marker and marker not in output):
        raise RuntimeError(f"{' '.join(map(str, command))}\n{output[-8000:]}")
    return output


def check_standalone(csound=None):
    with tempfile.TemporaryDirectory(prefix="mal-bundle-standalone-") as temporary:
        directory = Path(temporary)
        include = directory / bundle.artifact_name(bundle.read_version(ROOT))
        command = [sys.executable, str(ROOT / "tools/bundle.py"), "--output", str(include)]
        run(command, directory)
        first = include.read_bytes()
        run(command, directory)
        if include.read_bytes() != first:
            raise RuntimeError("Building the same sources twice changed the include file")
        text = first.decode("utf-8")
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        for expected in [f";; Version: {version}", ";; Author: Hlöðver Sigurðsson",
                         ";; SPDX-License-Identifier: MPL-2.0", ";; Source SHA-256:",
                         ";; Mozilla Public License Version 2.0"]:
            if expected not in text:
                raise RuntimeError(f"Missing bundle header: {expected}")
        commit = "unknown"
        if (ROOT / ".git").exists():
            try:
                revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                          capture_output=True, text=True)
                if revision.returncode == 0:
                    commit = revision.stdout.strip()
            except OSError:
                pass
        if f";; Commit: {commit}\n" not in text:
            raise RuntimeError("Bundle revision does not match its sources")
        print("PASS: repeatable build, versioned filename, license, and metadata", flush=True)
        if csound is None:
            return

        # These are host orchestras and test data. No library source files are copied.
        (directory / "src").mkdir()
        (directory / "tests").mkdir()
        original_include = '#include "src/main.orc"'
        bundled_include = f'#include "{include.name}"'
        for name in ["run.orc", "play.orc"]:
            host = (ROOT / "src" / name).read_text(encoding="utf-8")
            (directory / "src" / name).write_text(
                host.replace(original_include, bundled_include), encoding="utf-8")
        for name in ["check-file-loading.py", "check-csound-interop.py", "check-namespaces.py",
                     "core-helpers.mal", "clojure-forms.mal", "namespaces.mal",
                     "csound-interop.mal", "csound-catalog.mal", "csound-classic.mal",
                     "csound-arrays.mal"]:
            shutil.copy2(ROOT / "tests" / name, directory / "tests" / name)

        checkpoint = (ROOT / "tests/stepA-mal.orc").read_text(encoding="utf-8")
        checkpoint = checkpoint.replace(original_include, f"{bundled_include}\n{bundled_include}")
        checkpoint = checkpoint.replace("\nendin\n", '\n  prints "BUNDLE-CHECKPOINT-PASS\\n"\nendin\n')
        (directory / "checkpoint.orc").write_text(checkpoint, encoding="utf-8")
        run([csound, "-n", "-d", "-m128", "--orc", "checkpoint.orc"], directory,
            "BUNDLE-CHECKPOINT-PASS")
        print("PASS: standalone Step A and repeated inclusion", flush=True)
        run([csound, "-n", "-d", "-m128", "--orc", "src/run.orc", "--",
             "tests/core-helpers.mal"], directory, " core helper checks")
        print("PASS: bundled core helpers and macros", flush=True)
        run([csound, "-n", "-d", "-m128", "--orc", "src/run.orc", "--",
             "tests/clojure-forms.mal"], directory, " Clojure form and immutability checks")
        print("PASS: bundled Clojure forms, immutable values, and atoms", flush=True)

        forms = (ROOT / "tests/eval-forms.orc").read_text(encoding="utf-8")
        (directory / "eval-forms.orc").write_text(
            forms.replace(original_include, bundled_include), encoding="utf-8")
        run([csound, "-n", "-d", "-m128", "--orc", "eval-forms.orc"], directory,
            "PASS: multiple forms, session state, reader errors, and recovery")
        print("PASS: bundled region evaluation", flush=True)
        run([csound, "-n", "-d", "-m128", "--orc", "src/run.orc", "--",
             "tests/namespaces.mal"], directory, " namespace checks")
        sessions = (ROOT / "tests/namespace-sessions.orc").read_text(encoding="utf-8")
        (directory / "sessions.orc").write_text(
            sessions.replace(original_include, bundled_include), encoding="utf-8")
        run([csound, "-n", "-d", "-m128", "--orc", "sessions.orc"], directory,
            "PASS: namespace session isolation")
        print("PASS: bundled namespaces and session isolation", flush=True)
        for name in ["check-file-loading.py", "check-namespaces.py", "check-csound-interop.py"]:
            print(run([sys.executable, str(directory / "tests" / name), "--csound", csound],
                      directory, "PASS:").strip(), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csound", default=os.environ.get("CSOUND", "csound"))
    parser.add_argument("--build-only", action="store_true", help="check packaging without Csound")
    args = parser.parse_args()
    csound = None if args.build_only else shutil.which(args.csound)
    if csound is None and not args.build_only:
        parser.error(f"Csound executable not found: {args.csound}")
    tests = unittest.defaultTestLoader.loadTestsFromTestCase(IncludeTests)
    if not unittest.TextTestRunner().run(tests).wasSuccessful():
        return 1
    try:
        check_standalone(str(Path(csound).resolve()) if csound else None)
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
