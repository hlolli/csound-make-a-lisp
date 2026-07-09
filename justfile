set shell := ["zsh", "-cu"]

csound := "csound"
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @{{csound}} --version

test: smoke reader eval step3 step4 step5 unit harness-reader harness-eval harness-env harness-step4 harness-step5

smoke:
    {{csound}} {{csound_flags}} tests/step0-repl.orc

reader:
    {{csound}} {{csound_flags}} tests/step1-reader.orc

eval:
    {{csound}} {{csound_flags}} tests/step2-eval.orc

step3:
    {{csound}} {{csound_flags}} tests/step3-env.orc

step4:
    {{csound}} {{csound_flags}} tests/step4-if-do.orc

step4-if:
    @just step4

step5:
    {{csound}} {{csound_flags}} tests/step5-tco.orc

unit:
    {{csound}} {{csound_flags}} tests/unit-tests.orc

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

status:
    @git status --short
