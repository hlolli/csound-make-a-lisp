;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode CHECK_JOB(source:S, syncEnv:MalEnv, jobEnv:MalEnv):void
  ast:MalValue init read_str(source)
  expected:MalValue init EVAL(ast, syncEnv)
  id:i = MalEvalJobStart(ast, jobEnv)
  status:i = MalEvalJobStep(id, 0)
  pending:MalValue init MalEvalJobResult(id)
  if (id <= 0 || status != 0 || pending.type != $MAL_ERROR_TYPE) ithen
    prints "FAIL: job must start pending: %s\n", source
    exitnow(1)
  endif
  count:i = 0
  while (status == 0 && count < 200000) do
    status = MalEvalJobStep(id, 1)
    count += 1
  od
  actual:MalValue init MalEvalJobResult(id)
  if (status != 1 || strcmp(pr_str(actual), pr_str(expected)) != 0) ithen
    prints "FAIL: %s\nexpected: %s\nactual: %s\nstatus %d after %d steps\n", source, pr_str(expected), pr_str(actual), status, count
    exitnow(1)
  endif
  MalEvalJobCancel(id)
  if (MalEvalJobStep(id, 1) != -1) ithen
    prints "FAIL: cancelled job token must be invalid\n"
    exitnow(1)
  endif
endop

instr TEST
  syncEnv:MalEnv init MalMkStepAEnv()
  jobEnv:MalEnv init MalMkStepAEnv()
  CHECK_JOB("42", syncEnv, jobEnv)
  CHECK_JOB("(+ 1 (* 2 3))", syncEnv, jobEnv)
  CHECK_JOB("[1 (+ 2 3) {:a (+ 3 4)}]", syncEnv, jobEnv)
  CHECK_JOB("(do (def! x 7) (def y 3) [x y])", syncEnv, jobEnv)
  CHECK_JOB("(if false missing (+ x y))", syncEnv, jobEnv)
  CHECK_JOB("(if false 1)", syncEnv, jobEnv)
  CHECK_JOB("(do)", syncEnv, jobEnv)
  CHECK_JOB("(let* [a 1 b (+ a 2)] (+ a b))", syncEnv, jobEnv)
  CHECK_JOB("(let [a 1 f (fn [] a) a 2] [(f) a])", syncEnv, jobEnv)
  CHECK_JOB("(let [a 1] (+ a 2) (+ a 3))", syncEnv, jobEnv)
  CHECK_JOB("(do (defn f [a & more] [a more]) (f 1 2 3))", syncEnv, jobEnv)
  CHECK_JOB("(do (defn sum [n acc] (if (= n 0) acc (sum (- n 1) (+ acc n)))) (sum 100 0))", syncEnv, jobEnv)
  CHECK_JOB("(do (defmacro unless [test a b] (list 'if test b a)) (unless false 11 missing))", syncEnv, jobEnv)
  CHECK_JOB("(do (defmacro! twice (fn* [x] (list '+ x x))) (twice 9))", syncEnv, jobEnv)
  CHECK_JOB("`(a ~(+ 1 2) ~@(list 4 5))", syncEnv, jobEnv)
  CHECK_JOB("(and true 3 8)", syncEnv, jobEnv)
  CHECK_JOB("(or nil false 7)", syncEnv, jobEnv)
  CHECK_JOB("(try* (+ 1 (throw {:reason 42})) (catch* e (get e :reason)))", syncEnv, jobEnv)
  CHECK_JOB("(try* (try* (throw 5) (catch* e (throw (+ e 1)))) (catch* e (+ e 2)))", syncEnv, jobEnv)
  CHECK_JOB("(try* 12 (catch* e missing))", syncEnv, jobEnv)
  CHECK_JOB("(do (def saved (let [a 9] (fn [b] (+ a b)))) (saved 3))", syncEnv, jobEnv)
  CHECK_JOB("(saved 4)", syncEnv, jobEnv)
  CHECK_JOB("(do (ns job.example) (def answer 42) (ns user) job.example/answer)", syncEnv, jobEnv)
  CHECK_JOB("(do (require '[job.example :as e]) e/answer)", syncEnv, jobEnv)
  CHECK_JOB("(do (ns job.second (:require [job.example :as e])) e/answer (ns user))", syncEnv, jobEnv)
  CHECK_JOB("(ns 3 (:require unseen.library))", syncEnv, jobEnv)
  CHECK_JOB("(ns job.invalid (:require unseen.library) (:unsupported))", syncEnv, jobEnv)
  CHECK_JOB("(ns job.invalid (:require unseen.library [also.unseen :bad 1]))", syncEnv, jobEnv)
  CHECK_JOB("missing-symbol", syncEnv, jobEnv)
  CHECK_JOB("(if true)", syncEnv, jobEnv)
  CHECK_JOB("(let* [a 1 2 3] a)", syncEnv, jobEnv)
  CHECK_JOB("(let [a 1 2 3] a)", syncEnv, jobEnv)
  CHECK_JOB("(defmacro! bad 2)", syncEnv, jobEnv)
  CHECK_JOB("(fn [x x] x)", syncEnv, jobEnv)
  CHECK_JOB("(try* 1 (catch* 2 3))", syncEnv, jobEnv)
  CHECK_JOB("(f)", syncEnv, jobEnv)
  CHECK_JOB("(map (fn [x] (+ x 1)) [1 2 3])", syncEnv, jobEnv)
  CHECK_JOB("(mapv (fn [x] (* x x)) [1 2 3])", syncEnv, jobEnv)
  CHECK_JOB("(reduce + 10 [1 2 3])", syncEnv, jobEnv)
  CHECK_JOB("(filter odd? [1 2 3 4])", syncEnv, jobEnv)
  CHECK_JOB("(every? number? [1 2 3])", syncEnv, jobEnv)
  CHECK_JOB("(some (fn [x] (if (> x 2) x nil)) [1 2 3 4])", syncEnv, jobEnv)
  CHECK_JOB("(apply + [3 4])", syncEnv, jobEnv)
  CHECK_JOB("(eval '(+ 5 6))", syncEnv, jobEnv)
  CHECK_JOB("(meta (eval (with-meta [] {:x 1})))", syncEnv, jobEnv)
  CHECK_JOB("(meta (eval (with-meta (list) {:x 1})))", syncEnv, jobEnv)
  CHECK_JOB("(meta (eval (with-meta {} {:x 1})))", syncEnv, jobEnv)
  CHECK_JOB("(do (def counter (atom 0)) (swap! counter + 4) (deref counter))", syncEnv, jobEnv)
  CHECK_JOB("(update {:n 2} :n + 3)", syncEnv, jobEnv)
  CHECK_JOB("(update-in {:a {:n 2}} [:a :n] + 3)", syncEnv, jobEnv)

  ;; Another client can observe progress and run work between slices.
  id:i = MalEvalJobStart(read_str("(do (def stage 1) (def stage 2) (def stage 3))"), jobEnv)
  status:i = 0
  sawFirst:i = 0
  ticks:i = 0
  while (status == 0 && ticks < 1000) do
    status = MalEvalJobStep(id, 1)
    value:MalValue init MalResolveSymbol(jobEnv, "stage")
    if (value.type == $MAL_NUMBER_TYPE && value.number == 1) ithen
      sawFirst = 1
    endif
    ticks += 1
  od
  if (status != 1 || sawFirst != 1 || ticks < 4) ithen
    prints "FAIL: evaluation must return control between definitions\n"
    exitnow(1)
  endif
  MalEvalJobCancel(id)

  ;; Cancelling a pending job releases scopes and does not run later effects.
  id = MalEvalJobStart(read_str("(let [x 1] (do (def cancelled-write 1) x))"), jobEnv)
  status = MalEvalJobStep(id, 1)
  MalEvalJobCancel(id)
  value init MalResolveSymbol(jobEnv, "cancelled-write")
  if (value.type != $MAL_ERROR_TYPE || MalEvalJobStep(id, 1) != -1) ithen
    prints "FAIL: cancellation ran a pending effect\n"
    exitnow(1)
  endif
  replacement:i = MalEvalJobStart(read_str("17"), jobEnv)
  if (replacement == id) ithen
    prints "FAIL: stale job tokens must not refer to new jobs\n"
    exitnow(1)
  endif
  MalEvalJobCancel(replacement)

  ;; Tail calls release their prior call scopes rather than retaining one
  ;; scope and continuation per iteration until the whole job finishes.
  beforeLive:i = malEnvCount - malEnvFreeCount
  maximumLive:i = beforeLive
  maximumDepth:i = 0
  id = MalEvalJobStart(read_str("(sum 2000 0)"), jobEnv)
  status = 0
  ticks = 0
  while (status == 0 && ticks < 200000) do
    status = MalEvalJobStep(id, 1)
    maximumLive = max(maximumLive, malEnvCount - malEnvFreeCount)
    maximumDepth = max(maximumDepth, malEvalJobs[MalEvalJobSlot(id)].depth)
    ticks += 1
  od
  value init MalEvalJobResult(id)
  if (status != 1 || value.type != $MAL_NUMBER_TYPE || value.number != 2001000 || maximumLive > beforeLive + 8 || maximumDepth > 16) ithen
    prints "FAIL: tail calls grew live scopes or continuations: live %d -> %d, depth %d, value %s\n", beforeLive, maximumLive, maximumDepth, pr_str(value)
    exitnow(1)
  endif
  MalEvalJobCancel(id)

  first:i = MalEvalJobStart(read_str("(let [x 10] (+ x 1))"), jobEnv)
  second:i = MalEvalJobStart(read_str("(let [x 20] (+ x 1))"), jobEnv)
  firstStatus:i = 0
  secondStatus:i = 0
  while (firstStatus == 0 || secondStatus == 0) do
    firstStatus = MalEvalJobStep(first, 1)
    secondStatus = MalEvalJobStep(second, 1)
  od
  firstValue:MalValue init MalEvalJobResult(first)
  secondValue:MalValue init MalEvalJobResult(second)
  if (firstValue.number != 11 || secondValue.number != 21) ithen
    prints "FAIL: interleaved jobs shared a local scope\n"
    exitnow(1)
  endif
  MalEvalJobCancel(first)
  MalEvalJobCancel(second)

  ids:i[] init 16
  for index in [0 ... 15] do
    ids[index] = MalEvalJobStart(MalMkNumber(index), jobEnv)
  od
  if (MalEvalJobStart(MalMkNumber(17), jobEnv) != -1) ithen
    prints "FAIL: exhausted job slots must reject another start\n"
    exitnow(1)
  endif
  for index in [0 ... 15] do
    MalEvalJobCancel(ids[index])
  od
  prints "PASS: cooperative evaluation matches synchronous forms and yields between steps\n"
  exitnow(0)
endin

schedule("TEST", 0, 0)
