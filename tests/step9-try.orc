;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode REP_ENV(input:S, env:MalEnv):(S, MalEnv)
  ast:MalValue = read_str(input)
  currentEnv:MalEnv = env

  if (ast.type == $MAL_ERROR_TYPE) then
    result:S = ast.string
  else
    evaluated:MalValue, currentEnv = EVAL_ENV(ast, currentEnv)
    result = evaluated.type == $MAL_ERROR_TYPE ? \
      evaluated.string : pr_str(evaluated)
  endif

  xout result, currentEnv
endop

opcode ASSERT_REP_ENV(input:S, expected:S, env:MalEnv):MalEnv
  actual:S, updatedEnv:MalEnv = REP_ENV(input, env)

  if (strcmp(actual, expected) == 0) then
    prints "STEP9 %s, Assertion success\n", input
  else
    prints "STEP9 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

opcode ASSERT_THROW(input:S, expectedMessage:S, expectedPayload:S, \
                    env:MalEnv):MalEnv
  ast:MalValue = read_str(input)
  thrown:MalValue, updatedEnv:MalEnv = EVAL_ENV(ast, env)
  payload:MalValue = MalErrorPayload(thrown)
  actualPayload:S = pr_str(payload)

  if (thrown.type == $MAL_ERROR_TYPE && \
      strcmp(thrown.string, expectedMessage) == 0 && \
      strcmp(actualPayload, expectedPayload) == 0) then
    prints "STEP9 %s payload, Assertion success\n", input
  else
    prints "STEP9 %s payload, Assertion failed: expected message '%s' and payload '%s', got message '%s' and payload '%s'\n", \
      input, expectedMessage, expectedPayload, thrown.string, actualPayload
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 9 core behavior\n"
  env:MalEnv = MalMkStep9Env()

  env = ASSERT_REP_ENV("(throw \"uncaught\")", \
    "Error: \"uncaught\"", env)
  env = ASSERT_THROW("(throw \"err1\")", \
    "Error: \"err1\"", "\"err1\"", env)
  env = ASSERT_THROW("(throw (list 1 2 3))", \
    "Error: (1 2 3)", "(1 2 3)", env)
  env = ASSERT_THROW("(throw {:msg \"err2\"})", \
    "Error: {:msg \"err2\"}", "{:msg \"err2\"}", env)
  env = ASSERT_THROW("(throw nil)", "Error: nil", "nil", env)
  env = ASSERT_THROW("(cond true)", \
    "Error: \"odd number of forms to cond\"", \
    "\"odd number of forms to cond\"", env)

  env = ASSERT_REP_ENV("(throw)", \
    "throw: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(throw 1 2)", \
    "throw: expected 1 arguments, got 2", env)

  env = ASSERT_REP_ENV("(try* 123)", "123", env)
  env = ASSERT_REP_ENV("(try* missing)", "'missing' not found", env)
  env = ASSERT_REP_ENV("(try* 123 (catch* e 456))", "123", env)
  env = ASSERT_REP_ENV("(try* missing (catch* e e))", \
    "\"'missing' not found\"", env)
  env = ASSERT_REP_ENV("(try* (nth () 1) (catch* e e))", \
    "\"nth: index out of range\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw \"my exception\") (catch* e e))", \
    "\"my exception\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw (list 1 2 3)) (catch* e e))", \
    "(1 2 3)", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw {:msg \"err2\"}) (catch* e e))", \
    "{:msg \"err2\"}", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw 7) (catch* e (+ e 1)))", "8", env)
  env = ASSERT_REP_ENV( \
    "((fn* (x) (try* (throw 2) (catch* e (+ x e)))) 3)", \
    "5", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (def! before-catch 9) (throw \"failed\")) (catch* e before-catch))", \
    "9", env)
  env = ASSERT_REP_ENV("before-catch", "9", env)

  env = ASSERT_REP_ENV("(def! attempts (atom 0))", "(atom 0)", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (swap! attempts + 1) (list 1)) (catch* e 0))", \
    "(1)", env)
  env = ASSERT_REP_ENV("(deref attempts)", "1", env)
  env = ASSERT_REP_ENV("(reset! attempts 0)", "0", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (swap! attempts + 1) (throw \"once\")) (catch* e (deref attempts)))", \
    "1", env)

  env = ASSERT_REP_ENV( \
    "(try* (try* (throw \"e1\") (catch* e (throw \"e2\"))) (catch* e e))", \
    "\"e2\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (try* \"t1\" (catch* e \"c1\")) (throw \"e1\")) (catch* e \"c2\"))", \
    "\"c2\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw 7) (catch* caught caught))", "7", env)
  env = ASSERT_REP_ENV("caught", "'caught' not found", env)

  env = ASSERT_REP_ENV( \
    "(def! try-countdown (fn* (n) (if (= n 0) 0 (try* (try-countdown (- n 1))))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(try-countdown 2000)", "0", env)

  env = ASSERT_REP_ENV("(try*)", \
    "try*: expected 1 or 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(try* 1 2 3)", \
    "try*: expected 1 or 2 arguments, got 3", env)
  env = ASSERT_REP_ENV("(try* missing nil)", \
    "try*: second argument must be (catch* symbol handler)", env)
  env = ASSERT_REP_ENV("(try* 1 (catch* e))", \
    "try*: second argument must be (catch* symbol handler)", env)
  env = ASSERT_REP_ENV("(try* 1 (catch* 2 3))", \
    "catch*: binding must be a symbol", env)

  env = ASSERT_REP_ENV("(apply + (list 2 3))", "5", env)
  env = ASSERT_REP_ENV("(apply + 4 (list 5))", "9", env)
  env = ASSERT_REP_ENV("(apply + 4 [5])", "9", env)
  env = ASSERT_REP_ENV("(apply list (list))", "()", env)
  env = ASSERT_REP_ENV("(apply list 1 [])", "(1)", env)
  env = ASSERT_REP_ENV( \
    "(apply list 1 2 [3 4])", "(1 2 3 4)", env)

  env = ASSERT_REP_ENV("(def! apply-source [3 4])", "[3 4]", env)
  env = ASSERT_REP_ENV( \
    "(apply list 1 2 apply-source)", "(1 2 3 4)", env)
  env = ASSERT_REP_ENV("apply-source", "[3 4]", env)

  env = ASSERT_REP_ENV( \
    "(apply (fn* (a b) (+ a b)) (list 2 3))", "5", env)
  env = ASSERT_REP_ENV( \
    "(apply (fn* (a b) (+ a b)) 4 [5])", "9", env)
  env = ASSERT_REP_ENV( \
    "(apply (fn* (& more) (list? more)) [1 2 3])", "true", env)

  env = ASSERT_REP_ENV( \
    "(defmacro! add-macro (fn* (a b) (+ a b)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(apply add-macro (list 2 3))", "5", env)
  env = ASSERT_REP_ENV("(apply add-macro 4 [5])", "9", env)
  env = ASSERT_REP_ENV( \
    "(defmacro! ast-macro (fn* (a b) (list '+ a b)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(ast-macro 2 3)", "5", env)
  env = ASSERT_REP_ENV( \
    "(apply ast-macro (list 2 3))", "(+ 2 3)", env)

  env = ASSERT_REP_ENV( \
    "(try* (apply throw (list \"from apply\")) (catch* e e))", \
    "\"from apply\"", env)
  env = ASSERT_REP_ENV("(apply)", \
    "apply: expected at least 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(apply +)", \
    "apply: expected at least 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(apply + 1)", \
    "apply: final argument must be list or vector", env)
  env = ASSERT_REP_ENV("(apply 1 (list 2))", \
    "cannot apply 1", env)

  env = ASSERT_REP_ENV("(map str (list 1 true :a))", \
    "(\"1\" \"true\" \":a\")", env)
  env = ASSERT_REP_ENV("(map str [])", "()", env)
  env = ASSERT_REP_ENV("(def! map-source [1 2 3])", \
    "[1 2 3]", env)
  env = ASSERT_REP_ENV( \
    "(map (fn* (x) (* 2 x)) map-source)", "(2 4 6)", env)
  env = ASSERT_REP_ENV("map-source", "[1 2 3]", env)
  env = ASSERT_REP_ENV( \
    "(map (fn* (& values) (list? values)) [1 2])", \
    "(true true)", env)

  env = ASSERT_REP_ENV( \
    "(defmacro! map-ast (fn* (x) (list '+ x 1)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(map map-ast [1 2])", \
    "((+ 1 1) (+ 2 1))", env)

  env = ASSERT_REP_ENV("(def! map-calls (atom 0))", \
    "(atom 0)", env)
  env = ASSERT_REP_ENV( \
    "(def! stop-map (fn* (x) (do (swap! map-calls + 1) (if (= x 2) (throw \"stop\") x))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV( \
    "(try* (map stop-map [1 2 3]) (catch* e e))", \
    "\"stop\"", env)
  env = ASSERT_REP_ENV("(deref map-calls)", "2", env)
  env = ASSERT_REP_ENV( \
    "(try* (map throw (list \"mapped error\")) (catch* e e))", \
    "\"mapped error\"", env)

  env = ASSERT_REP_ENV("(map)", \
    "map: expected 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(map str)", \
    "map: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(map str [] [])", \
    "map: expected 2 arguments, got 3", env)
  env = ASSERT_REP_ENV("(map str 1)", \
    "map: second argument must be list or vector", env)
  env = ASSERT_REP_ENV("(map 1 [2])", "cannot apply 1", env)

  env = ASSERT_REP_ENV("(nil? nil)", "true", env)
  env = ASSERT_REP_ENV("(nil? false)", "false", env)
  env = ASSERT_REP_ENV("(nil? true)", "false", env)
  env = ASSERT_REP_ENV("(nil? (list))", "false", env)
  env = ASSERT_REP_ENV("(nil? 0)", "false", env)

  env = ASSERT_REP_ENV("(true? true)", "true", env)
  env = ASSERT_REP_ENV("(true? false)", "false", env)
  env = ASSERT_REP_ENV("(true? nil)", "false", env)
  env = ASSERT_REP_ENV("(true? 1)", "false", env)
  env = ASSERT_REP_ENV("(true? true?)", "false", env)

  env = ASSERT_REP_ENV("(false? false)", "true", env)
  env = ASSERT_REP_ENV("(false? true)", "false", env)
  env = ASSERT_REP_ENV("(false? nil)", "false", env)
  env = ASSERT_REP_ENV("(false? \"\")", "false", env)
  env = ASSERT_REP_ENV("(false? 0)", "false", env)
  env = ASSERT_REP_ENV("(false? [])", "false", env)
  env = ASSERT_REP_ENV("(false? {})", "false", env)

  env = ASSERT_REP_ENV("(symbol? 'abc)", "true", env)
  env = ASSERT_REP_ENV("(symbol? \"abc\")", "false", env)
  env = ASSERT_REP_ENV("(symbol? :abc)", "false", env)
  env = ASSERT_REP_ENV("(symbol? 1)", "false", env)

  env = ASSERT_REP_ENV("(apply nil? (list nil))", "true", env)
  env = ASSERT_REP_ENV( \
    "(map symbol? (list 'abc 1 \"abc\"))", \
    "(true false false)", env)

  env = ASSERT_REP_ENV("(nil?)", \
    "nil?: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(true? true false)", \
    "true?: expected 1 arguments, got 2", env)
  env = ASSERT_REP_ENV("(false?)", \
    "false?: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(symbol? 'a 'b)", \
    "symbol?: expected 1 arguments, got 2", env)

  prints "Testing Step 9 collection core functions\n"

  env = ASSERT_REP_ENV("(symbol \"abc\")", "abc", env)
  env = ASSERT_REP_ENV("(keyword \"abc\")", ":abc", env)
  env = ASSERT_REP_ENV("(keyword :abc)", ":abc", env)
  env = ASSERT_REP_ENV("(keyword? :abc)", "true", env)
  env = ASSERT_REP_ENV("(keyword? \"abc\")", "false", env)

  env = ASSERT_REP_ENV("(vector 1 2 3)", "[1 2 3]", env)
  env = ASSERT_REP_ENV("(vector? [])", "true", env)
  env = ASSERT_REP_ENV("(vector? '(1 2))", "false", env)
  env = ASSERT_REP_ENV("(sequential? [1])", "true", env)
  env = ASSERT_REP_ENV("(sequential? (list 1))", "true", env)
  env = ASSERT_REP_ENV("(sequential? {})", "false", env)

  env = ASSERT_REP_ENV("(hash-map :a 1 :a 2)", "{:a 2}", env)
  env = ASSERT_REP_ENV("(map? {})", "true", env)
  env = ASSERT_REP_ENV("(map? [])", "false", env)
  env = ASSERT_REP_ENV("(count {:a 1 :b 2})", "2", env)

  env = ASSERT_REP_ENV("(def! source-map {:a 1 :b 2})", \
    "{:a 1 :b 2}", env)
  env = ASSERT_REP_ENV("(assoc source-map :a 3 :c 4)", \
    "{:a 3 :b 2 :c 4}", env)
  env = ASSERT_REP_ENV("source-map", "{:a 1 :b 2}", env)
  env = ASSERT_REP_ENV("(dissoc source-map :a :missing)", \
    "{:b 2}", env)
  env = ASSERT_REP_ENV("source-map", "{:a 1 :b 2}", env)

  env = ASSERT_REP_ENV("(get source-map :a)", "1", env)
  env = ASSERT_REP_ENV("(get source-map :missing)", "nil", env)
  env = ASSERT_REP_ENV("(get nil :missing)", "nil", env)
  env = ASSERT_REP_ENV("(contains? source-map :b)", "true", env)
  env = ASSERT_REP_ENV("(contains? source-map :missing)", "false", env)
  env = ASSERT_REP_ENV("(keys source-map)", "(:a :b)", env)
  env = ASSERT_REP_ENV("(vals source-map)", "(1 2)", env)
  env = ASSERT_REP_ENV("(keys {})", "()", env)
  env = ASSERT_REP_ENV("(vals {})", "()", env)

  env = ASSERT_REP_ENV("(= {:a 1 :b [2 3]} {:b (list 2 3) :a 1})", \
    "true", env)
  env = ASSERT_REP_ENV("(= {:a {:b 2}} {:a {:b 2}})", \
    "true", env)
  env = ASSERT_REP_ENV("(= {:a 1} {:a 2})", "false", env)
  env = ASSERT_REP_ENV("(= {:a 1} {:a 1 :b 2})", "false", env)
  env = ASSERT_REP_ENV("(get {\"abc\" 1 :abc 2} \"abc\")", "1", env)
  env = ASSERT_REP_ENV("(get {\"abc\" 1 :abc 2} :abc)", "2", env)
  env = ASSERT_REP_ENV("(keys {:a 1 :a 2})", "(:a)", env)
  env = ASSERT_REP_ENV("(pr-str true false nil :key 'sym)", \
    "\"true false nil :key sym\"", env)

  env = ASSERT_REP_ENV("(symbol 1)", \
    "symbol: expected string argument", env)
  env = ASSERT_REP_ENV("(keyword 1)", \
    "keyword: expected string or keyword argument", env)
  env = ASSERT_REP_ENV("(hash-map :a)", \
    "hash-map: expected even number of arguments", env)
  env = ASSERT_REP_ENV("(assoc {} :a)", \
    "assoc: expected key/value pairs", env)
  env = ASSERT_REP_ENV("(assoc [] :a 1)", \
    "assoc: first argument must be a hash map", env)
  env = ASSERT_REP_ENV("(dissoc [])", \
    "dissoc: first argument must be a hash map", env)
  env = ASSERT_REP_ENV("(get [] :a)", \
    "get: first argument must be a hash map or nil", env)
  env = ASSERT_REP_ENV("(contains? [] :a)", \
    "contains?: first argument must be a hash map", env)
  env = ASSERT_REP_ENV("(keys [])", \
    "keys: expected hash map argument", env)
  env = ASSERT_REP_ENV("(vals [])", \
    "vals: expected hash map argument", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
