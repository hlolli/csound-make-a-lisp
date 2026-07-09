set shell := ["zsh", "-cu"]

csound := "csound"
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @{{csound}} --version

test: smoke reader eval step3 step4-if unit harness-reader harness-eval harness-env

smoke:
    {{csound}} {{csound_flags}} tests/step0-repl.orc

reader:
    {{csound}} {{csound_flags}} tests/step1-reader.orc

eval:
    {{csound}} {{csound_flags}} tests/step2-eval.orc

step3:
    {{csound}} {{csound_flags}} tests/step3-env.orc

step4-if:
    {{csound}} {{csound_flags}} tests/step4-if.orc

unit:
    {{csound}} {{csound_flags}} tests/unit-tests.orc

harness-reader:
    python3 mal/runtest.py --deferrable --optional tests/harness/step1_read_print.mal -- tests/harness/run-step1-reader

harness-eval:
    python3 mal/runtest.py --deferrable --optional tests/harness/step2_eval.mal -- tests/harness/run-step2-eval

harness-env:
    python3 mal/runtest.py --deferrable --no-optional tests/harness/step3_env.mal -- tests/harness/run-step3-env

status:
    @git status --short
