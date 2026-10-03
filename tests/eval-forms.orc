;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode CHECK_FORMS(source:S, expected:S, env:MalEnv):MalEnv
  value:MalValue, nextEnv:MalEnv = MalEvalFormsEnv(source, env)
  actual:S init pr_str(value)
  if (strcmp(actual, expected) != 0) ithen
    prints "FAIL: %s: expected %s, got %s\n", source, expected, actual
    exitnow(1)
  endif
  xout nextEnv
endop

instr TEST
  env:MalEnv init MalMkStepAEnv()
  env init CHECK_FORMS("; only a comment", "nil", env)
  env init CHECK_FORMS("", "nil", env)
  env init CHECK_FORMS("(read-string \"(+ 1 2)\") (+ 3 4)", "7", env)
  env init CHECK_FORMS("(ns live) (def counter (atom 0))", "(atom 0)", env)
  env init CHECK_FORMS("(defn tick! [] (swap! counter inc)) (tick!) @counter ; trailing comment", "1", env)
  env init CHECK_FORMS("(tick!) @counter", "2", env)
  env init CHECK_FORMS("(ns user) @live/counter", "2", env)

  ;; Reject stray closing delimiters instead of ignoring the rest of the region.
  value:MalValue, env = MalEvalFormsEnv(") (reset! live/counter 99)", env)
  if (value.type != $MAL_ERROR_TYPE) ithen
    prints "FAIL: expected a reader error\n"
    exitnow(1)
  endif
  env init CHECK_FORMS("@live/counter", "2", env)

  value, env = MalEvalFormsEnv("(reset! live/counter 99) (", env)
  if (value.type != $MAL_ERROR_TYPE) ithen
    prints "FAIL: expected an incomplete-form error\n"
    exitnow(1)
  endif
  env init CHECK_FORMS("@live/counter", "2", env)

  ;; Keep completed definitions, stop at the error, and allow the next call.
  value, env = MalEvalFormsEnv("(def kept 42) missing-name (reset! live/counter 99)", env)
  if (value.type != $MAL_ERROR_TYPE) ithen
    prints "FAIL: expected an evaluation error\n"
    exitnow(1)
  endif
  env init CHECK_FORMS("[kept @live/counter]", "[42 2]", env)
  prints "PASS: multiple forms, session state, reader errors, and recovery\n"
  exitnow(0)
endin

schedule("TEST", 0, 0)
