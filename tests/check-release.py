#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Check release filenames, version validation, and release-note fallbacks."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import bundle
import release


class VersionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mal-release-version-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def version(self, text):
        (self.root / "VERSION").write_text(text, encoding="utf-8")
        return bundle.read_version(self.root)

    def test_versions_allow_prereleases_and_build_metadata(self):
        for version in ("0.1.0", "2.0.0-rc.1", "2.0.0+build.5", "2.0.0-rc.1+build.5"):
            with self.subTest(version=version):
                self.assertEqual(self.version(version + "\n"), version)

    def test_versions_reject_invalid_or_unsafe_names(self):
        for version in ("", "v1.0.0", "1.0", "01.0.0", "1.0.0-01", "1.0.0-rc..1",
                        "1.0.0\n2.0.0", "../1.0.0", "1.0.0/extra", "1.0.0; echo bad"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.version(version)

    def test_one_version_sets_the_filename_and_header(self):
        (self.root / "src").mkdir()
        (self.root / "src/main.orc").write_text('Svalue init "hello"\n', encoding="utf-8")
        (self.root / "LICENSE").write_text("Example license\n", encoding="utf-8")
        version = self.version("1.2.3-rc.1\n")
        output = self.root / "dist" / bundle.artifact_name(version)
        bundle.build(self.root, output)
        self.assertEqual(output.name, "mal-1.2.3-rc.1.inc")
        self.assertIn(";; Version: 1.2.3-rc.1\n", output.read_text(encoding="utf-8"))


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mal-release-notes-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.data = {
            "version": "1.2.3",
            "tag": "v1.2.3",
            "asset": "mal-1.2.3.inc",
            "repository": "example/mal",
            "previous_tag": "v1.2.2",
            "changes": [{"commit": "a" * 40, "subject": "fix: keep [items] in order"}],
        }
        (self.directory / "release.json").write_text(json.dumps(self.data), encoding="utf-8")
        self.notes = self.directory / "release-notes.md"
        self.fallback = release.render_notes(self.data)
        self.notes.write_text(self.fallback, encoding="utf-8")

    def test_fallback_links_to_the_commits_and_version_range(self):
        self.assertIn(r"keep \[items\] in order", self.fallback)
        self.assertIn("https://github.com/example/mal/commit/" + "a" * 40, self.fallback)
        self.assertIn("/compare/v1.2.2...v1.2.3", self.fallback)
        self.assertIn("`mal-1.2.3.inc`", self.fallback)

    def test_first_release_links_to_its_history(self):
        self.data["previous_tag"] = ""
        notes = release.render_notes(self.data)
        self.assertIn("/commits/v1.2.3", notes)
        self.assertNotIn("/compare/", notes)

    def test_missing_or_failed_llama_keeps_the_commit_list(self):
        for error in (FileNotFoundError("ollama"), subprocess.TimeoutExpired("ollama", 300),
                      subprocess.CalledProcessError(1, "ollama")):
            with self.subTest(error=type(error).__name__):
                with patch.object(release.subprocess, "run", side_effect=error):
                    release.summarize(self.directory)
                self.assertEqual(self.notes.read_text(encoding="utf-8"), self.fallback)

    def test_empty_or_malformed_llama_output_keeps_the_commit_list(self):
        for text in ("", "Here are your notes:", "- " + "x" * 501):
            with self.subTest(text=text[:30]):
                result = subprocess.CompletedProcess([], 0, stdout=text)
                with patch.object(release.subprocess, "run", return_value=result):
                    release.summarize(self.directory)
                self.assertEqual(self.notes.read_text(encoding="utf-8"), self.fallback)

    def test_llama_summary_keeps_the_download_and_history_links(self):
        result = subprocess.CompletedProcess([], 0, stdout="- Keep items in order.\n")
        with patch.object(release.subprocess, "run", return_value=result):
            release.summarize(self.directory)
        notes = self.notes.read_text(encoding="utf-8")
        self.assertTrue(notes.startswith("- Keep items in order.\n"))
        self.assertIn("`mal-1.2.3.inc`", notes)
        self.assertIn("/compare/v1.2.2...v1.2.3", notes)


if __name__ == "__main__":
    unittest.main()
