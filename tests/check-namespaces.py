#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Exercise namespace loading through the script runner with real files."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csound", default=os.environ.get("CSOUND", "csound"))
    args = parser.parse_args()
    binary = shutil.which(args.csound)
    if binary is None:
        parser.error(f"Csound executable not found: {args.csound}")

    with tempfile.TemporaryDirectory(prefix="mal namespaces λ ") as temporary:
        directory = Path(temporary)
        fixtures = {
            "music/math.mal": """
                (ns music.math)
                (swap! user/visits conj :math)
                (defn twice [x] (* 2 x))
            """,
            "music/low_notes.mal": """
                (ns music.low-notes (:require [music.math :as m]))
                (swap! user/visits conj :notes)
                (def state (atom [110]))
                (defn octave [x] (m/twice x))
            """,
            "cycle/a.mal": "(ns cycle.a (:require cycle.b))",
            "cycle/b.mal": "(ns cycle.b (:require cycle.a))",
            "retry.mal": """
                (ns retry)
                (swap! user/attempts inc)
                (if (= 1 @user/attempts) (throw :first-attempt) nil)
                (def value :loaded)
            """,
            "wrong.mal": "(ns different) (def value :wrong)",
            "undeclared.mal": "(def value :no-ns)",
            "unwanted.mal": "(ns unwanted) (swap! user/visits conj :unwanted)",
            "direct.mal": "(ns direct) (def value 9)",
            "broken.mal": "(ns broken) (throw :broken-file)",
            "syntax.mal": "(ns syntax) (",
        }
        for name, source in fixtures.items():
            path = directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(source, encoding="utf-8")
        source = """
(defn check [label expected actual]
  (if (= expected actual) nil (throw (str label ": " (pr-str actual)))))
(defn caught [form] (try* (eval form) (catch* e e)))
(def visits (atom []))
(def attempts (atom 0))
(ns app (:require [music.low-notes :as notes :refer [octave]]))
(user/check "relative nested require" 220 (octave 110))
(user/check "caller namespace restored" 'app *ns*)
(user/check "load order" [:math :notes] @user/visits)
(require 'music.low-notes '[music.low-notes :as notes])
(user/check "require loads once" [:math :notes] @user/visits)
(swap! notes/state conj 220)
(user/check "shared atom" [110 220] @music.low-notes/state)
(user/check "module alias stays private" true
  (try* (m/twice 1) (catch* e true)))
(ns user)
(check "missing library" "require: could not find missing/library.mal"
  (caught '(require 'missing.library)))
(check "cycle" "require: circular dependency on 'cycle.a'"
  (caught '(require 'cycle.a)))
(check "cycle restores caller" 'user *ns*)
(check "cycle retry is not marked loaded" "require: circular dependency on 'cycle.a'"
  (caught '(require 'cycle.a)))
(check "module failure" :first-attempt (caught '(require 'retry)))
(check "failed module restores caller" 'user *ns*)
(require 'retry)
(check "retry succeeds" :loaded retry/value)
(check "retry evaluated file again" 2 @attempts)
(check "invalid options fail before loading" true
  (string? (caught '(require 'unwanted '[music.math :unknown value]))))
(check "invalid options have no file side effects" [:math :notes] @visits)
(check "wrong ns is rejected" true
  (string? (caught '(require 'wrong))))
(check "missing ns declaration is rejected" true
  (string? (caught '(require 'undeclared))))
(check "wrong ns restores caller" 'user *ns*)
(check "load-file result" nil (load-file DIRECT_FILE))
(check "load-file namespace" 'user *ns*)
(check "file owns its definition" 9 direct/value)
(check "load-file error" :broken-file (caught '(load-file BROKEN_FILE)))
(check "load-file error namespace" 'user *ns*)
(check "reader error" true (string? (caught '(load-file SYNTAX_FILE))))
(check "reader error namespace" 'user *ns*)
(check "failed ns require restores caller" true
  (string? (caught '(ns failed (:require missing.library)))))
(check "failed ns namespace" 'user *ns*)
(println "NAMESPACE-LOADING-PASS")
"""
        for placeholder, name in [("DIRECT_FILE", "direct.mal"),
                                  ("BROKEN_FILE", "broken.mal"),
                                  ("SYNTAX_FILE", "syntax.mal")]:
            source = source.replace(placeholder, json.dumps(str(directory / name), ensure_ascii=False))
        script = directory / "check.mal"
        script.write_text(source, encoding="utf-8")
        try:
            result = subprocess.run(
                [str(Path(binary).resolve()), "-n", "-d", "-m128", "--orc",
                 str(ROOT / "src/run.orc"), "--", str(script)],
                cwd=ROOT, capture_output=True, text=True, timeout=60,
            )
        except subprocess.TimeoutExpired:
            print("FAIL: namespace loading exceeded 60 seconds", file=sys.stderr)
            return 1
        output = result.stdout + result.stderr
        if result.returncode or "NAMESPACE-LOADING-PASS" not in output.splitlines():
            print(f"FAIL: namespace loading\n{output}", file=sys.stderr)
            return 1
    print("PASS: namespace files, aliases, atoms, load-once, cycles, errors, and retry")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
