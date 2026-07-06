set shell := ["zsh", "-cu"]

csound := "csound"
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @{{csound}} --version

test: smoke reader eval unit harness-reader harness-eval

smoke:
    {{csound}} {{csound_flags}} tests/step0-repl.orc

reader:
    {{csound}} {{csound_flags}} tests/step1-reader.orc

eval:
    {{csound}} {{csound_flags}} tests/step2-eval.orc

unit:
    {{csound}} {{csound_flags}} tests/unit-tests.orc

harness-reader:
    python3 mal/runtest.py --deferrable --optional tests/harness/step1_read_print.mal -- tests/harness/run-step1-reader

harness-eval:
    python3 mal/runtest.py --deferrable --optional tests/harness/step2_eval.mal -- tests/harness/run-step2-eval

status:
    @git status --short
