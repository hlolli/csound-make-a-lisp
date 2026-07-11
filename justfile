set shell := ["zsh", "-cu"]

csound := "csound"
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @{{csound}} --version

test: smoke reader eval step3 step4 step5 step6 step7 step8 step9 unit harness-reader harness-eval harness-env harness-step4 harness-step5 harness-step6 harness-step7 harness-step8 harness-step9

smoke:
    {{csound}} {{csound_flags}} tests/step0-repl.orc

repl:
    @{{csound}} -d -m0 -odac -+rtaudio=null --orc src/repl.orc

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

step6:
    {{csound}} {{csound_flags}} tests/step6-file.orc

step7:
    {{csound}} {{csound_flags}} tests/step7-quote.orc

step8:
    {{csound}} {{csound_flags}} tests/step8-macros.orc

step9:
    {{csound}} {{csound_flags}} tests/step9-try.orc

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

harness-step6:
    python3 mal/runtest.py --test-timeout 120 --no-deferrable --no-optional tests/harness/step6_file.mal -- tests/harness/run-step6-file

harness-step7:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step7_quote.mal -- tests/harness/run-step7-quote

harness-step8:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step8_macros.mal -- tests/harness/run-step8-macros

harness-step9:
    python3 mal/runtest.py --test-timeout 120 --deferrable --optional tests/harness/step9_try.mal -- tests/harness/run-step9-try

status:
    @git status --short
