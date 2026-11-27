# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

set shell := ["zsh", "-cu"]

csound := env_var_or_default("CSOUND", "csound")
export CSOUND := csound
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @"$CSOUND" --version

build:
    python3 tools/bundle.py

bundle-check:
    python3 tests/check-bundle.py --csound "$CSOUND"

release-check:
    python3 tests/check-bundle.py --build-only
    python3 tests/check-release.py

test: test-native test-reference

test-native: launchers bundle-check release-check smoke repl-check reader eval step3 step4 step5 step6 file-loading step7 step8 step9 step-a script-args unit core-helpers clojure-forms clojure-helpers clojure-language eval-jobs namespaces csound-interop

test-reference: test-reference-basic test-reference-language

test-reference-basic: harness-reader harness-eval harness-env harness-step4 harness-step5 harness-step6

test-reference-language: harness-step7 harness-step8 harness-step9 harness-stepA harness-threading harness-csound

launchers:
    python3 tests/check-launchers.py

smoke:
    "$CSOUND" {{csound_flags}} tests/step0-repl.orc

repl:
    @"$CSOUND" -d -m0 -odac -+rtaudio=null --orc src/repl.orc

repl-check:
    python3 tests/check-repl.py "$CSOUND"

row-row-row:
    ./play examples/row-row-row.mal

reader:
    "$CSOUND" {{csound_flags}} tests/step1-reader.orc

eval:
    "$CSOUND" {{csound_flags}} tests/step2-eval.orc

step3:
    "$CSOUND" {{csound_flags}} tests/step3-env.orc

step4:
    "$CSOUND" {{csound_flags}} tests/step4-if-do.orc

step4-if:
    @just step4

step5:
    "$CSOUND" {{csound_flags}} tests/step5-tco.orc

step6:
    "$CSOUND" {{csound_flags}} tests/step6-file.orc

file-loading:
    python3 tests/check-file-loading.py --csound "$CSOUND"

step7:
    "$CSOUND" {{csound_flags}} tests/step7-quote.orc

step8:
    "$CSOUND" {{csound_flags}} tests/step8-macros.orc

step9:
    "$CSOUND" {{csound_flags}} tests/step9-try.orc

step-a:
    "$CSOUND" {{csound_flags}} tests/stepA-mal.orc

script-args:
    ./run tests/stepA-script-args.mal first "two words" --gain=0.5 ""

unit:
    "$CSOUND" {{csound_flags}} tests/unit-tests.orc

harness-reader:
    python3 mal/runtest.py --deferrable --optional tests/harness/step1_read_print.mal -- tests/harness/run-step1-reader

harness-eval:
    python3 mal/runtest.py --deferrable --optional tests/harness/step2_eval.mal -- tests/harness/run-step2-eval

harness-env:
    python3 mal/runtest.py --deferrable --no-optional tests/harness/step3_env.mal -- tests/harness/run-step3-env

harness-step4:
    python3 mal/runtest.py --no-deferrable --no-optional tests/harness/step4_if_fn_do.mal -- tests/harness/run-step4-if-fn-do

harness-step5:
    python3 mal/runtest.py --test-timeout 120 --no-deferrable --no-optional tests/harness/step5_tco.mal -- tests/harness/run-step5-tco
    python3 mal/runtest.py --test-timeout 120 --no-deferrable --no-optional tests/harness/step5_mutual_tco.mal -- tests/harness/run-step5-tco

harness-step6:
    python3 mal/runtest.py --test-timeout 120 --no-deferrable --no-optional tests/harness/step6_file.mal -- tests/harness/run-step6-file

harness-step7:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step7_quote.mal -- tests/harness/run-step7-quote

harness-step8:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step8_macros.mal -- tests/harness/run-step8-macros

harness-step9:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step9_try.mal -- tests/harness/run-step9-try

harness-stepA:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/stepA_mal.mal -- tests/harness/run-stepA-mal

core-helpers:
    ./run tests/core-helpers.mal

clojure-forms:
    ./run tests/clojure-forms.mal

clojure-helpers:
    ./run tests/clojure-helpers.mal

clojure-language:
    "$CSOUND" {{csound_flags}} tests/clojure-language.orc
    "$CSOUND" {{csound_flags}} tests/loop-memory.orc

eval-forms:
    "$CSOUND" {{csound_flags}} tests/eval-forms.orc

eval-jobs:
    "$CSOUND" {{csound_flags}} tests/eval-job.orc
    "$CSOUND" {{csound_flags}} tests/eval-job-builtins.orc
    python3 tests/check-native-host.py "$CSOUND" {{csound_flags}} tests/native.orc

namespaces:
    ./run tests/namespaces.mal
    "$CSOUND" {{csound_flags}} tests/namespace-sessions.orc
    python3 tests/check-namespaces.py --csound "$CSOUND"

wasm-native module bundle:
    node tests/check-native-host.mjs "{{module}}" "{{bundle}}"

harness-threading:
    python3 mal/runtest.py --test-timeout 120 --no-deferrable --no-optional tests/harness/threading.mal -- tests/harness/run-stepA-mal

harness-csound:
    python3 mal/runtest.py --no-deferrable --no-optional tests/harness/csound_interop.mal -- tests/harness/run-csound-interop

csound-interop:
    python3 tests/check-csound-interop.py --csound "$CSOUND"

selfhost:
    python3 tests/selfhost/check.py --csound "$CSOUND"

selfhost-step-a:
    python3 tests/selfhost/check.py --csound "$CSOUND" --steps A

status:
    @git status --short
