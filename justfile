set shell := ["zsh", "-cu"]

csound := "csound"
csound_flags := "-n -d -m128 --orc"

default:
    @just --list

version:
    @{{csound}} --version

test: smoke reader

smoke:
    {{csound}} {{csound_flags}} tests/step0-repl.orc

reader:
    {{csound}} {{csound_flags}} tests/step1-reader.orc

unit:
    {{csound}} {{csound_flags}} tests/unit-tests.orc

status:
    @git status --short
