;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, you can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode RunLoopTest(ast:MalValue, env:MalEnv, resumable:i):MalValue
  if (resumable == 0) ithen
    result:MalValue init EVAL(ast, env)
  else
    id:i = MalEvalJobStart(ast, env)
    status:i = 0
    slices:i = 0
    while (status == 0 && slices < 10000) do
      status = MalEvalJobStep(id, 31)
      slices += 1
    od
    result init MalEvalJobResult(id)
    MalEvalJobCancel(id)
    if (status != 1) ithen
      prints "FAIL: nested loop job did not complete\n"
      exitnow(1)
    endif
  endif
  xout result
endop

opcode CheckLoopGrowth(label:S, ast:MalValue, env:MalEnv, resumable:i):void
  live:i = malEnvCount - malEnvFreeCount
  env init MalEnvSet(env, "loop-test-size", MalMkNumber(2))
  warm:MalValue init RunLoopTest(ast, env, resumable)
  if (warm.type != $MAL_NUMBER_TYPE || warm.number != 4) ithen
    prints "FAIL: %s warmup returned %s\n", label, pr_str(warm)
    exitnow(1)
  endif

  functions:i = malFunctionCount
  nodes:i = malAstNodeCount
  scopes:i = malEnvCount
  env init MalEnvSet(env, "loop-test-size", MalMkNumber(30))
  actual:MalValue init RunLoopTest(ast, env, resumable)
  if (actual.type != $MAL_NUMBER_TYPE || actual.number != 60) ithen
    prints "FAIL: %s returned %s\n", label, pr_str(actual)
    exitnow(1)
  endif
  if (malFunctionCount != functions || malAstNodeCount != nodes || \
      malEnvCount - malEnvFreeCount != live || malEnvCount > scopes + 4) ithen
    prints "FAIL: %s mode %d retained functions %d, AST nodes %d, or scopes %d (allocated %d)\n", \
      label, resumable, malFunctionCount - functions, malAstNodeCount - nodes, \
      malEnvCount - malEnvFreeCount - live, malEnvCount - scopes
    exitnow(1)
  endif
endop

opcode CheckLoopCleanup(ast:MalValue, expected:S, env:MalEnv, resumable:i):void
  live:i = malEnvCount - malEnvFreeCount
  functions:i = malFunctionCount
  nodes:i = malAstNodeCount
  actual:MalValue init RunLoopTest(ast, env, resumable)
  if (strcmp(pr_str(actual), expected) != 0 || malEnvCount - malEnvFreeCount != live || \
      malFunctionCount != functions || malAstNodeCount != nodes) ithen
    prints "FAIL: loop cleanup mode %d expected %s, got %s\n", resumable, expected, pr_str(actual)
    exitnow(1)
  endif
endop

instr TEST
  env:MalEnv init MalMkStepAEnv()
  value:MalValue, env = MalEvalFormsEnv({{
    (defn loop-finish [x] x)
    (defn loop-tail [n] (loop [i n] (if (pos? i) (loop-tail (dec i)) i)))
  }}, env)
  nestedLoop:MalValue init read_str({{
    (loop [i 0 total 0]
      (if (< i loop-test-size)
        (recur (inc i) (loop [j 0 sum total]
                         (if (< j 2) (recur (inc j) (inc sum)) sum)))
        total))
  }})
  nestedDoseq:MalValue init read_str({{
    (let [visits (atom 0)]
      (doseq [i (range loop-test-size) j [1 2]] (swap! visits inc))
      (deref visits))
  }})
  readers:MalValue init read_str({{
    (loop [i 0 saved []]
      (if (< i 2)
        (recur (inc i)
               (loop [j 0 saved saved]
                 (if (< j 2) (recur (inc j) (conj saved (fn [] [i j]))) saved)))
        saved))
  }})
  tailCall:MalValue init read_str("(loop [i 0] (if (< i 5) (recur (inc i)) (loop-finish i)))")
  shortTail:MalValue init read_str("(loop-tail 2)")
  longTail:MalValue init read_str("(loop-tail 60)")
  localWrite:MalValue init read_str("(let [y 10] (loop [x (do (def! y 99) 1) z y] [y x z]))")
  initializerClosure:MalValue init read_str("(let [i 10] (loop [i (inc i) f (fn [] i)] [(f) i]))")
  caughtError:MalValue init read_str("(try* (dotimes [i 5] (dotimes [j 5] (throw :stop))) (catch* e e))")
  malformedMarker:MalValue init read_str({{
    (let [marker (first (core/iteration 'loop '([i 0] i)))]
      [(try* (marker) (catch* e :caught))
       (try* (apply marker []) (catch* e :caught))
       (try* (eval (list marker)) (catch* e :caught))])
  }})
  for resumable in [0 ... 1] do
    CheckLoopGrowth("nested loop", nestedLoop, env, resumable)
    CheckLoopGrowth("nested doseq", nestedDoseq, env, resumable)
    CheckLoopCleanup(tailCall, "5", env, resumable)
    CheckLoopCleanup(localWrite, "[10 1 99]", env, resumable)
    CheckLoopCleanup(caughtError, ":stop", env, resumable)
    CheckLoopCleanup(malformedMarker, "[:caught :caught :caught]", env, resumable)
    CheckLoopCleanup(shortTail, "0", env, resumable)
    scopes:i = malEnvCount
    CheckLoopCleanup(longTail, "0", env, resumable)
    if (malEnvCount > scopes + 4) ithen
      prints "FAIL: tail calls through loops in mode %d added %d scope slots\n", resumable, malEnvCount - scopes
      exitnow(1)
    endif

    initializerResult:MalValue init RunLoopTest(initializerClosure, env, resumable)
    if (strcmp(pr_str(initializerResult), "[11 11]") != 0) ithen
      prints "FAIL: closure in a loop initializer mode %d returned %s\n", resumable, pr_str(initializerResult)
      exitnow(1)
    endif

    ;; The loop targets have gone away. Reuse some scope slots before reading
    ;; the genuine user closures, including those returned by a cancelled job.
    captured:MalValue init RunLoopTest(readers, env, resumable)
    CheckLoopCleanup(tailCall, "5", env, resumable)
    if (captured.type != $MAL_VECTOR_TYPE || captured.length != 4) ithen
      prints "FAIL: expected four nested loop closures, got %s\n", pr_str(captured)
      exitnow(1)
    endif
    for index in [0 ... 3] do
      closure:MalValue init MalAt(captured, index)
      pair:MalValue init MalApply(closure, MalMkValue($MAL_LIST_TYPE))
      expected:S init sprintf("[%d %d]", int(index / 2), index % 2)
      if (strcmp(pr_str(pair), expected) != 0) ithen
        prints "FAIL: escaping closure mode %d expected %s, got %s\n", resumable, expected, pr_str(pair)
        exitnow(1)
      endif
    od
  od

  env init MalEnvSet(env, "loop-test-progress", MalMkBool(0))
  live:i = malEnvCount - malEnvFreeCount
  functions:i = malFunctionCount
  nodes:i = malAstNodeCount
  cancellable:MalValue init read_str({{
    (dotimes [i 9]
      (dotimes [j 9]
        (def loop-test-progress true)
        (+ i j)))
  }})
  id:i = MalEvalJobStart(cancellable, env)
  status:i = 0
  steps:i = 0
  progress:MalValue init MalMkBool(0)
  while (status == 0 && steps < 2000 && progress.type != $MAL_TRUE_TYPE) do
    status = MalEvalJobStep(id, 1)
    progress init MalResolveSymbol(env, "loop-test-progress")
    steps += 1
  od
  if (status != 0 || progress.type != $MAL_TRUE_TYPE || malEnvCount - malEnvFreeCount <= live) ithen
    prints "FAIL: expected pending job inside a nested loop\n"
    exitnow(1)
  endif
  ;; A second job may release and reuse its own slots while this one is live.
  CheckLoopCleanup(tailCall, "5", env, 1)
  MalEvalJobCancel(id)
  if (MalEvalJobStep(id, 0) != -1 || malEnvCount - malEnvFreeCount != live || \
      malFunctionCount != functions || malAstNodeCount != nodes) ithen
    prints "FAIL: cancelled nested loop job retained evaluator state\n"
    exitnow(1)
  endif
  CheckLoopCleanup(tailCall, "5", env, 1)

  value, env = MalEvalFormsEnv({{
    (ns loop.before) (def captured 11)
    (ns loop.after) (def captured 22)
  }}, env)
  namespaceInitializer:MalValue init read_str("(loop [ignored (do (ns loop.after) 0)] captured)")
  namespaceRecur:MalValue init read_str("(loop [i 0] (if (= i 0) (do (ns loop.after) (recur 1)) captured))")
  for resumable in [0 ... 1] do
    value, env = MalEvalSourceEnv("(ns loop.before)", env)
    CheckLoopCleanup(namespaceInitializer, "11", env, resumable)
    value, env = MalEvalSourceEnv("(ns loop.before)", env)
    CheckLoopCleanup(namespaceRecur, "11", env, resumable)
  od
  prints "PASS: nested loop storage stays bounded and escaping closures remain valid\n"
  exitnow(0)
endin
schedule("TEST", 0, 0)
