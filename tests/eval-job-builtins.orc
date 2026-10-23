;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode AssertJobBuiltin(source:S, env:MalEnv):void
  ast:MalValue init read_str(source)
  expected:MalValue, updated:MalEnv = EVAL_ENV(ast, env)
  token:i = MalEvalJobStart(ast, env)
  steps:i = 0
  status:i = 0
  while (status == 0 && steps < 100000) do
    status = MalEvalJobStep(token, 1)
    steps += 1
  od
  actual:MalValue init MalEvalJobResult(token)
  expectedText:S init pr_str(expected)
  actualText:S init pr_str(actual)
  if (expected.type == $MAL_ERROR_TYPE) ithen
    expectedText init pr_str(MalErrorPayload(expected))
  endif
  if (actual.type == $MAL_ERROR_TYPE) ithen
    actualText init pr_str(MalErrorPayload(actual))
  endif
  if (status != 1 || expected.type != actual.type || strcmp(expectedText, actualText) != 0) ithen
    prints "JOB BUILTIN failed: %s\nexpected %s, got %s (status %d)\n", source, expectedText, actualText, status
    exitnow(1)
  endif
  MalEvalJobCancel(token)
  prints "JOB BUILTIN passed: %s\n", source
endop

opcode AssertJobBuiltinExpected(source:S, expected:S, env:MalEnv):void
  token:i = MalEvalJobStart(read_str(source), env)
  steps:i = 0
  status:i = 0
  while (status == 0 && steps < 100000) do
    status = MalEvalJobStep(token, 1)
    steps += 1
  od
  actual:MalValue init MalEvalJobResult(token)
  if (status != 1 || actual.type == $MAL_ERROR_TYPE || strcmp(pr_str(actual), expected) != 0) ithen
    prints "JOB BUILTIN failed: %s\nexpected %s, got %s (status %d)\n", source, expected, pr_str(actual), status
    exitnow(1)
  endif
  MalEvalJobCancel(token)
  prints "JOB BUILTIN passed: %s\n", source
endop

instr TEST
  env:MalEnv init MalMkCsoundEnv()
  AssertJobBuiltin("(apply + 1 2 [3 4])", env)
  AssertJobBuiltin("(apply (fn [a b] (+ a b)) [3 4])", env)
  AssertJobBuiltin("(apply +)", env)
  AssertJobBuiltin("(apply + nil)", env)
  AssertJobBuiltin("(apply 12 [])", env)
  AssertJobBuiltin("(map (fn [x] (* x x)) [1 2 3])", env)
  AssertJobBuiltin("(map 12 [])", env)
  AssertJobBuiltin("(map inc nil)", env)
  AssertJobBuiltin("(map inc [1 :bad 3])", env)
  AssertJobBuiltin("(map inc)", env)
  AssertJobBuiltin("(mapv + [1 2 3] [10 20])", env)
  AssertJobBuiltin("(mapv (fn [x] x) \"abc\")", env)
  AssertJobBuiltin("(mapv 12 nil [1 2])", env)
  AssertJobBuiltin("(mapv inc 12)", env)
  AssertJobBuiltin("(mapv inc)", env)
  AssertJobBuiltin("(reduce + [1 2 3])", env)
  AssertJobBuiltin("(reduce + 10 [1 2 3])", env)
  AssertJobBuiltin("(reduce (fn [] (reduced 7)) [])", env)
  AssertJobBuiltin("(reduce 12 [(reduced 7)])", env)
  AssertJobBuiltin("(reduce (fn [sum x] (if (= x 3) (reduced sum) (+ sum x))) 0 [1 2 3 4])", env)
  AssertJobBuiltin("(reduce + nil)", env)
  AssertJobBuiltin("(reduce + 1 nil)", env)
  AssertJobBuiltin("(reduce + 1 2 3)", env)
  AssertJobBuiltin("(reduce + 1)", env)
  AssertJobBuiltin("(filter (fn [x] (> x 1)) [0 1 2 3])", env)
  AssertJobBuiltin("(filterv (fn [x] (> x 1)) [0 1 2 3])", env)
  AssertJobBuiltin("(remove (fn [x] (> x 1)) [0 1 2 3])", env)
  AssertJobBuiltin("(keep (fn [x] (if (= x 2) nil (if (= x 1) false x))) [0 1 2 3])", env)
  AssertJobBuiltin("(some (fn [x] (if (> x 2) x nil)) [1 2 3 4])", env)
  AssertJobBuiltin("(some (fn [x] false) [1 2])", env)
  AssertJobBuiltin("(every? number? [1 2 3])", env)
  AssertJobBuiltin("(every? number? [1 nil 3])", env)
  AssertJobBuiltin("(not-every? number? [1 nil 3])", env)
  AssertJobBuiltin("(not-any? number? [:a nil])", env)
  AssertJobBuiltin("(not-any? number? [:a 2 nil])", env)
  AssertJobBuiltin("(every? 12 [])", env)
  AssertJobBuiltin("(not-every? 12 [])", env)
  AssertJobBuiltin("(some 12 [])", env)
  AssertJobBuiltin("(not-any? 12 [])", env)
  AssertJobBuiltin("(keep 12 [])", env)
  AssertJobBuiltin("(filterv 12 [])", env)
  AssertJobBuiltin("(filter inc 12)", env)
  AssertJobBuiltin("(every? inc)", env)
  AssertJobBuiltin("(take-while (fn [x] (< x 3)) [1 2 3 1])", env)
  AssertJobBuiltin("(drop-while (fn [x] (< x 3)) [1 2 3 1])", env)
  AssertJobBuiltin("(let [seen (atom [])] (list (drop-while (fn [x] (do (swap! seen conj x) (< x 3))) [1 2 3 1]) (deref seen)))", env)
  AssertJobBuiltin("(take 2.2 [1 2 3 4])", env)
  AssertJobBuiltin("(drop 2.2 [1 2 3 4])", env)
  AssertJobBuiltin("(take -1 [1 2])", env)
  AssertJobBuiltin("(drop -1 [1 2])", env)
  AssertJobBuiltin("(take :bad 12)", env)
  AssertJobBuiltin("(drop 2 12)", env)
  AssertJobBuiltin("(let [a (atom 3)] (list (swap! a + 4 5) (deref a)))", env)
  AssertJobBuiltin("(let [a (atom 3)] (list (try* (swap! a (fn [x] (throw :bad))) (catch* e e)) (deref a)))", env)
  AssertJobBuiltin("(swap! 1 inc)", env)
  AssertJobBuiltin("(swap!)", env)
  AssertJobBuiltin("(update {:x 2} :x + 3 4)", env)
  AssertJobBuiltin("(update-in {:x {:y 2}} [:x :y] + 3 4)", env)
  AssertJobBuiltin("(update-in nil [] (fn [x] 4))", env)
  AssertJobBuiltin("(update-in nil [:x :y] (fn [x] 4))", env)
  AssertJobBuiltin("(update [1 2] 2 (fn [x] 3))", env)
  AssertJobBuiltin("(update [1 2] :x inc)", env)
  AssertJobBuiltin("(update-in {} 1 inc)", env)
  AssertJobBuiltin("(update-in {})", env)
  AssertJobBuiltin("(try* (filter (fn [x] (throw :bad)) [1 2]) (catch* e e))", env)
  AssertJobBuiltin("(try* (map (fn [x] (throw :bad)) [1 2]) (catch* e e))", env)
  AssertJobBuiltin("(let [x 2] (list (eval '(+ 3 4)) x))", env)
  AssertJobBuiltin("(eval)", env)
  AssertJobBuiltin("(require 'csound)", env)
  AssertJobBuiltin("(require '[csound :as sound])", env)
  AssertJobBuiltin("(require 1)", env)
  AssertJobBuiltin("(load-file)", env)
  AssertJobBuiltin("(load-file 1)", env)
  AssertJobBuiltin("(map inc (csound/array :i [1 2 3]))", env)
  AssertJobBuiltin("(reduce + (csound/array :i [1 2 3]))", env)
  ;; Jobs also allow eval as a function value, beyond direct eval forms.
  AssertJobBuiltinExpected("(apply eval ['(+ 1 2)])", "3", env)
  AssertJobBuiltinExpected("(map eval ['(+ 1 2) '(+ 3 4)])", "(3 7)", env)
  AssertJobBuiltinExpected("(let [x 9] (list (apply eval ['(+ 1 2)]) x))", "(3 9)", env)

  shared:MalValue init MalMkAtom(MalMkNumber(0))
  calls:MalValue init MalMkAtom(MalMkNumber(0))
  env init MalEnvSet(env, "shared", shared)
  env init MalEnvSet(env, "calls", calls)
  source:S init "(swap! shared (fn [x] (do (swap! calls inc) (+ x 1))))"
  token:i = MalEvalJobStart(read_str(source), env)
  status:i = 0
  changed:i = 0
  steps:i = 0
  while (status == 0 && steps < 100000) do
    status = MalEvalJobStep(token, 1)
    count:MalValue init MalAtomValue(calls)
    if (changed == 0 && count.number == 1) ithen
      ignored:MalValue init MalAtomSetValue(shared, MalMkNumber(100))
      ignored init MalAtomSetValue(shared, MalMkNumber(0))
      changed = 1
    endif
    steps += 1
  od
  actual:MalValue init MalEvalJobResult(token)
  count:MalValue init MalAtomValue(calls)
  stored:MalValue init MalAtomValue(shared)
  if (status != 1 || actual.number != 1 || stored.number != 1 || count.number != 2 || changed != 1) ithen
    prints "JOB BUILTIN swap retry failed: status %d, result %s, atom %s, calls %s\n", status, pr_str(actual), pr_str(stored), pr_str(count)
    exitnow(1)
  endif
  MalEvalJobCancel(token)
  prints "JOB BUILTIN passed: swap! retries after an intervening write and restore\n"
  prints "All cooperative builtin comparisons passed\n"
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
