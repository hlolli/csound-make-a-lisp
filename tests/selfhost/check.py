#!/usr/bin/env python3
"""Run the reference MAL interpreters inside Csound MAL with bounded resources."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "mal/impls/mal"
STEPS = {
    "1": ("step1_read_print", ['(1 "two" :three)', "[1 2 3]"],
          ['(1 "two" :three)', "[1 2 3]"]),
    "2": ("step2_eval", ["(+ 20 22)", "[1 (+ 20 22)]"], ["42", "[1 42]"]),
    "3": ("step3_env", ["(def! x 40)", "(let* (y 2) (+ x y))"], ["40", "42"]),
    "4": ("step4_if_fn_do", ["((fn* (n) (+ n 2)) 40)",
          "(do (def! make-adder (fn* (n) (fn* (x) (+ n x)))) ((make-adder 12) 30))"],
          ["42", "42"]),
    "6": ("step6_file", None, None),
    "7": ("step7_quote", None, None),
    "8": ("step8_macros", None, None),
    "9": ("step9_try", None, None),
    "A": ("stepA_mal", None, None),
}


def run_bounded(command, timeout, max_mb, env):
    start = time.monotonic()
    peak_mb = 0.0
    with tempfile.TemporaryFile(mode="w+") as output:
        proc = subprocess.Popen(command, cwd=REFERENCE, env=env,
                                stdout=output, stderr=subprocess.STDOUT)
        try:
            while proc.poll() is None:
                usage = subprocess.run(["ps", "-o", "rss=", "-p", str(proc.pid)],
                                       capture_output=True, text=True, check=False, timeout=2)
                if usage.returncode == 0:
                    peak_mb = max(peak_mb, int(usage.stdout.strip() or 0) / 1024)
                elif proc.poll() is None:
                    raise RuntimeError(f"cannot monitor Csound memory: {usage.stderr.strip()}")
                if peak_mb > max_mb:
                    raise RuntimeError(f"exceeded {max_mb:g} MiB memory limit")
                if time.monotonic() - start > timeout:
                    raise RuntimeError(f"exceeded {timeout:g}s timeout")
                time.sleep(0.05)
            output.seek(0)
            text = output.read()
            if proc.returncode:
                raise RuntimeError(f"Csound exited {proc.returncode}\n{text[-6000:]}")
            return text, time.monotonic() - start, peak_mb
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csound", default=os.environ.get("CSOUND", "csound"))
    parser.add_argument("--steps", nargs="+", choices=STEPS, default=list(STEPS))
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--max-mb", type=float, default=1536)
    args = parser.parse_args()
    binary = shutil.which(args.csound)
    if binary is None:
        parser.error(f"Csound executable not found: {args.csound}")
    binary = str(Path(binary).resolve())
    if not (REFERENCE / "stepA_mal.mal").is_file():
        parser.error(f"reference MAL checkout missing: {REFERENCE}")
    if args.timeout <= 0 or args.max_mb <= 0:
        parser.error("timeout and memory limit must be positive")
    env = dict(os.environ)
    with tempfile.TemporaryDirectory(prefix="mal-selfhost-") as temporary:
        for step in args.steps:
            name, inputs, expected = STEPS[step]
            reference = str(REFERENCE / (name + ".mal"))
            if inputs is not None:
                orchestra = ROOT / "tests/selfhost/repl.orc"
                script_args = [reference, *inputs]
            else:
                orchestra = ROOT / "src/run.orc"
                source = (ROOT / "tests/selfhost/smoke.mal").read_text()
                if step in "789A":
                    source += '\n(check "quasiquote" \'(1 2 3 4) `(1 ~(+ 1 1) ~@(list 3 4)))\n'
                if step in "89A":
                    source += "\n(defmacro! unless (fn* (test yes no) (list 'if test no yes)))\n"
                    source += '(check "macro" 42 (unless false (+ 20 22) 0))\n'
                if step in "9A":
                    source += '(check "exception" "caught" (try* (throw "caught") (catch* error error)))\n'
                if step == "A":
                    source += '(check "host language" "Csound7-mal" *host-language*)\n'
                    source += '(check "metadata" {:doc "answer"} (meta (with-meta (list 42) {:doc "answer"})))\n'
                marker = f"SELFHOST-{step}-PASS"
                source += f'(println "{marker}")\n'
                script = Path(temporary) / (name + ".mal")
                script.write_text(source)
                script_args = [reference, str(script), "first", "two words", "--gain=0.5", ""]
                expected = ["SELFHOST-COMMON-PASS", marker]
            command = [binary, "-n", "-d", "-m128", f"--env:INCDIR={ROOT}",
                       "--orc", str(orchestra), "--", *script_args]
            try:
                output, elapsed, peak = run_bounded(command, args.timeout, args.max_mb, env)
                lines = output.splitlines()
                if "Error:" in output or "Uncaught exception:" in output:
                    raise RuntimeError(output[-6000:])
                position = 0
                for expected_line in expected:
                    try:
                        position = lines.index(expected_line, position) + 1
                    except ValueError:
                        raise RuntimeError(f"missing output {expected_line!r}\n{output[-6000:]}") from None
            except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
                print(f"FAIL self-hosted Step {step}: {error}", file=sys.stderr, flush=True)
                return 1
            print(f"PASS self-hosted Step {step}: {elapsed:.2f}s, sampled peak {peak:.1f} MiB", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
