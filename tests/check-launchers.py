#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check build selection and argument handling through the actual launchers."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LAUNCHERS = ("play", "run", "run-selfhost")


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mal launchers ")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name).resolve()
        self.root = self.directory / "project"
        self.root.mkdir()
        (self.root / "mal/impls/mal").mkdir(parents=True)
        for name in LAUNCHERS:
            shutil.copy2(ROOT / name, self.root / name)
        helper = ROOT / "src/csound-env.sh"
        if helper.exists():
            (self.root / "src").mkdir()
            shutil.copy2(helper, self.root / "src/csound-env.sh")
        self.system = self.make_binary("system")
        self.local = self.make_binary("local build")
        self.override = self.make_binary("override")
        (self.root / ".csound-build").symlink_to(self.local.parent)
        self.env = os.environ.copy()
        self.env.pop("CSOUND", None)
        self.env.pop("OPCODE7DIR64", None)
        self.env["PATH"] = str(self.system.parent) + os.pathsep + self.env["PATH"]

    def make_binary(self, name):
        binary = self.directory / name / "csound"
        binary.parent.mkdir()
        binary.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "print(json.dumps({'binary': os.path.realpath(__file__), "
            "'plugins': os.environ.get('OPCODE7DIR64'), 'args': sys.argv[1:]}))\n"
        )
        binary.chmod(0o755)
        return binary

    def launch(self, name):
        return subprocess.run(
            [str(self.root / name), "my score.mal", "two words", ""],
            cwd=self.directory, env=self.env, text=True, capture_output=True,
            timeout=10,
        )

    def test_local_build_and_arguments(self):
        for name in LAUNCHERS:
            with self.subTest(launcher=name):
                run = self.launch(name)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = json.loads(run.stdout)
                self.assertEqual(result["binary"], str(self.local))
                self.assertEqual(Path(result["plugins"]).resolve(), self.local.parent)
                self.assertEqual(result["args"][-3:],
                                 [str(self.directory / "my score.mal"), "two words", ""])

    def test_explicit_overrides(self):
        self.env["CSOUND"] = "override/csound"
        self.env["OPCODE7DIR64"] = str(self.directory / "custom plugins")
        for name in LAUNCHERS:
            with self.subTest(launcher=name):
                run = self.launch(name)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = json.loads(run.stdout)
                self.assertEqual(result["binary"], str(self.override))
                self.assertEqual(result["plugins"], self.env["OPCODE7DIR64"])

    def test_system_fallback(self):
        (self.root / ".csound-build").unlink()
        for name in LAUNCHERS:
            with self.subTest(launcher=name):
                run = self.launch(name)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = json.loads(run.stdout)
                self.assertEqual(result["binary"], str(self.system))
                self.assertIsNone(result["plugins"])

    def test_broken_local_build_fails(self):
        self.local.unlink()
        for name in LAUNCHERS:
            with self.subTest(launcher=name):
                run = self.launch(name)
                self.assertNotEqual(run.returncode, 0)
                self.assertIn(".csound-build", run.stderr)
                self.assertEqual(run.stdout, "")


if __name__ == "__main__":
    unittest.main()
