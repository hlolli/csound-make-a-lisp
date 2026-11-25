;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

ksmps = 16

nativeTestEnv@global:MalEnv init MalMkStepAEnv()

opcode NativeEcho(frame:i):i
  args:MalValue init MalNativeArgs(frame)
  ;; Repeated evalstr calls used to retain another 8 MiB on each invocation.
  scratch:i[] init 1048576
  first:MalValue init MalAt(args, 0)
  scratch[0] = first.number
  xout MalNativeReturn(frame, args)
endop

opcode NativeReenter(frame:i):i
  args:MalValue init MalNativeArgs(frame)
  callback:MalValue init MalAt(args, 0)
  number:MalValue init MalAt(args, 1)
  if (number.number <= 0) ithen
    result:MalValue init number
  else
    nested:MalValue init MalMkValue($MAL_LIST_TYPE)
    nested init MalAppendValue(nested, callback)
    nested init MalAppendValue(nested, MalMkNumber(number.number - 1))
    result init MalApply(callback, nested)
    if (result.type != $MAL_ERROR_TYPE) ithen
      result init MalMkNumber(result.number + number.number)
    endif
  endif
  xout MalNativeReturn(frame, result)
endop

opcode NativeError(frame:i):i
  xout MalNativeReturn(frame, MalMkError("host error"))
endop

opcode NativeInitError(frame:i):i
  values:i[] init 1
  index:i = frame + 1
  xout values[index]
endop

opcode CHECK_NATIVE(source:S, expected:S, env:MalEnv):void
  actual:MalValue init EVAL(read_str(source), env)
  if (strcmp(pr_str(actual), expected) != 0) ithen
    prints "FAIL: %s\nexpected %s, got %s\n", source, expected, pr_str(actual)
    exitnow(1)
  endif
endop

instr RegisterNativeTestBindings
  setksmps(1)
  nativeTestEnv init MalEnvSet(nativeTestEnv, "echo", MalMkNative("NativeEcho"))
  nativeTestEnv init MalEnvSet(nativeTestEnv, "reenter", MalMkNative("NativeReenter"))
  nativeTestEnv init MalEnvSet(nativeTestEnv, "fail-init", MalMkNative("NativeInitError"))
  CHECK_NATIVE("(echo :small-block)", "(:small-block)", nativeTestEnv)
  CHECK_NATIVE("(try* (reenter fail-init 1) (catch* e e))", "\"native: host initialization failed\"", nativeTestEnv)
endin

instr TEST
  env:MalEnv init nativeTestEnv
  ;; Use the full call depth after the other instrument's nested init error.
  CHECK_NATIVE("(reenter reenter 63)", "2016", env)
  env init MalEnvSet(env, "fail", MalMkNative("NativeError"))
  CHECK_NATIVE("(fn? echo)", "true", env)
  CHECK_NATIVE("(echo 3 :a [4 5])", "(3 :a [4 5])", env)
  CHECK_NATIVE("(do (def saved (echo 7)) (echo 8) saved)", "(7)", env)
  CHECK_NATIVE("(apply echo [9 10])", "(9 10)", env)
  CHECK_NATIVE("(map echo [1 2 3])", "((1) (2) (3))", env)
  CHECK_NATIVE("(reenter reenter 10)", "55", env)
  CHECK_NATIVE("(try* (fail) (catch* e e))", "\"host error\"", env)
  CHECK_NATIVE("(try* (reenter reenter 64) (catch* e e))", "\"native: host call nesting exceeds 64\"", env)
  CHECK_NATIVE("(reenter reenter 5)", "15", env)
  ;; Register through one call site too: a new binding must not reuse an
  ;; earlier binding's opcode objects or retarget a captured function value.
  names:S[] fillarray "first-echo", "second-fail", "last-echo"
  targets:S[] fillarray "NativeEcho", "NativeError", "NativeEcho"
  for binding in [0 ... 2] do
    env init MalEnvSet(env, names[binding], MalMkNative(targets[binding]))
  od
  CHECK_NATIVE("(first-echo 31)", "(31)", env)
  CHECK_NATIVE("(try* (second-fail) (catch* e e))", "\"host error\"", env)
  CHECK_NATIVE("(last-echo 42)", "(42)", env)
  ;; Test the job evaluator and reuse of both arguments and returned storage.
  for index in [0 ... 149] do
    source:S init sprintf("(echo %d)", index)
    id:i = MalEvalJobStart(read_str(source), env)
    status:i = 0
    steps:i = 0
    while (status == 0 && steps < 1000) do
      status = MalEvalJobStep(id, 1)
      steps += 1
    od
    result:MalValue init MalEvalJobResult(id)
    first:MalValue init MalAt(result, 0)
    if (status != 1 || first.type != $MAL_NUMBER_TYPE || first.number != index) ithen
      prints "FAIL: native job %d returned %s\n", index, pr_str(result)
      exitnow(1)
    endif
    MalEvalJobCancel(id)
  od
  CHECK_NATIVE("saved", "(7)", env)
  prints "PASS: native functions, callbacks, errors, reuse, and evaluation jobs\n"
  exitnow(0)
endin
schedule("RegisterNativeTestBindings", 0, 0)
schedule("TEST", 0, 0)
