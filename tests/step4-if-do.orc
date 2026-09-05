;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop

opcode PRINT(ast:MalValue):S
  xout pr_str_with_readability(ast, 1)
endop

opcode REP_ENV(input:S, env:MalEnv):(S, MalEnv)
  ast:MalValue = READ(input)
  currentEnv:MalEnv = env

  if (ast.type == $MAL_ERROR_TYPE) then
    result:S = ast.string
  else
    evaluated:MalValue, currentEnv = EVAL_ENV(ast, currentEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated.string
    else
      result = PRINT(evaluated)
    endif
  endif

  xout result, currentEnv
endop

opcode ASSERT_REP_ENV(input:S, expected:S, env:MalEnv):MalEnv
  actual:S, updatedEnv:MalEnv = REP_ENV(input, env)

  if (strcmp(actual, expected) == 0) then
    prints "STEP4 %s, Assertion success\n", input
  else
    prints "STEP4 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 4 if, do, and fn* special forms\n"
  env:MalEnv = MalMkStep2Env()

  env = ASSERT_REP_ENV("(list)", "()", env)
  env = ASSERT_REP_ENV("(list? (list))", "true", env)
  env = ASSERT_REP_ENV("(list? nil)", "false", env)
  env = ASSERT_REP_ENV("(empty? (list))", "true", env)
  env = ASSERT_REP_ENV("(empty? (list 1))", "false", env)
  env = ASSERT_REP_ENV("(list 1 2 3)", "(1 2 3)", env)
  env = ASSERT_REP_ENV("(count (list 1 2 3))", "3", env)
  env = ASSERT_REP_ENV("(count (list))", "0", env)
  env = ASSERT_REP_ENV("(count nil)", "0", env)

  env = ASSERT_REP_ENV("(if true 7 8)", "7", env)
  env = ASSERT_REP_ENV("(if false 7 8)", "8", env)
  env = ASSERT_REP_ENV("(if nil 7 8)", "8", env)
  env = ASSERT_REP_ENV("(if false 7 false)", "false", env)
  env = ASSERT_REP_ENV("(if false (+ 1 7))", "nil", env)
  env = ASSERT_REP_ENV("(if nil 8)", "nil", env)
  env = ASSERT_REP_ENV("(if true (+ 1 7))", "8", env)

  env = ASSERT_REP_ENV("(if 0 7 8)", "7", env)
  env = ASSERT_REP_ENV("(if [] 7 8)", "7", env)
  env = ASSERT_REP_ENV("(if {} 7 8)", "7", env)
  env = ASSERT_REP_ENV("(if \"\" 7 8)", "7", env)

  env = ASSERT_REP_ENV("(if true (+ 1 7) (+ 1 8))", "8", env)
  env = ASSERT_REP_ENV("(if false (+ 1 7) (+ 1 8))", "9", env)
  env = ASSERT_REP_ENV("(if true 1 (abc))", "1", env)
  env = ASSERT_REP_ENV("(if false (abc) 2)", "2", env)
  env = ASSERT_REP_ENV("(if (abc) 1 2)", "'abc' not found", env)

  env = ASSERT_REP_ENV("(= 1 1)", "true", env)
  env = ASSERT_REP_ENV("(= 1 2)", "false", env)
  env = ASSERT_REP_ENV("(= nil nil)", "true", env)
  env = ASSERT_REP_ENV("(= nil false)", "false", env)
  env = ASSERT_REP_ENV("(= (list 1 2) (list 1 2))", "true", env)
  env = ASSERT_REP_ENV("(= (list 1) (list))", "false", env)
  env = ASSERT_REP_ENV("(> 2 1)", "true", env)
  env = ASSERT_REP_ENV("(>= 1 1)", "true", env)
  env = ASSERT_REP_ENV("(< 1 2)", "true", env)
  env = ASSERT_REP_ENV("(<= 2 1)", "false", env)
  env = ASSERT_REP_ENV("(not false)", "true", env)
  env = ASSERT_REP_ENV("(not 0)", "false", env)

  env = ASSERT_REP_ENV("(def! branch 0)", "0", env)
  env = ASSERT_REP_ENV("(if true (def! branch 1) (def! branch 2))", "1", env)
  env = ASSERT_REP_ENV("branch", "1", env)
  env = ASSERT_REP_ENV("(if false (def! branch 3) (def! branch 4))", "4", env)
  env = ASSERT_REP_ENV("branch", "4", env)

  env = ASSERT_REP_ENV("(if)", "if: expected 2 or 3 arguments, got 0", env)
  env = ASSERT_REP_ENV("(if true)", "if: expected 2 or 3 arguments, got 1", env)
  env = ASSERT_REP_ENV("(if true 1 2 3)", \
    "if: expected 2 or 3 arguments, got 4", env)

  env = ASSERT_REP_ENV("(do)", "nil", env)
  env = ASSERT_REP_ENV("(do 7)", "7", env)
  env = ASSERT_REP_ENV("(do 7 8)", "8", env)
  env = ASSERT_REP_ENV("(do (+ 1 2) (+ 3 4))", "7", env)
  env = ASSERT_REP_ENV("(do (def! a 6) 7 (+ a 8))", "14", env)
  env = ASSERT_REP_ENV("a", "6", env)
  env = ASSERT_REP_ENV("(do (prn 101) 7)", "7", env)
  env = ASSERT_REP_ENV("(do (def! sequenced 1) (def! sequenced (+ sequenced 1)) sequenced)", \
    "2", env)
  env = ASSERT_REP_ENV("sequenced", "2", env)
  env = ASSERT_REP_ENV("(do (abc) (def! should-not-exist 1))", "'abc' not found", env)
  env = ASSERT_REP_ENV("should-not-exist", "'should-not-exist' not found", env)

  env = ASSERT_REP_ENV("((fn* (a b) (+ b a)) 3 4)", "7", env)
  env = ASSERT_REP_ENV("((fn* () 4))", "4", env)
  env = ASSERT_REP_ENV("((fn* () ()))", "()", env)
  env = ASSERT_REP_ENV("((fn* (f x) (f x)) (fn* (a) (+ 1 a)) 7)", "8", env)

  env = ASSERT_REP_ENV("(((fn* (a) (fn* (b) (+ a b))) 5) 7)", "12", env)
  env = ASSERT_REP_ENV("(def! gen-plus5 (fn* () (fn* (b) (+ 5 b))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(def! plus5 (gen-plus5))", "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(plus5 7)", "12", env)
  env = ASSERT_REP_ENV("(def! gen-plusX (fn* (x) (fn* (b) (+ x b))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(def! plus7 (gen-plusX 7))", "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(plus7 8)", "15", env)
  env = ASSERT_REP_ENV("(let* [b 0 f (fn* [] b)] (let* [b 1] (f)))", \
    "0", env)
  env = ASSERT_REP_ENV("((let* [b 0] (fn* [] b)))", "0", env)
  env = ASSERT_REP_ENV("(let* (f (fn* () x) x 3) (f))", "3", env)
  env = ASSERT_REP_ENV("(let* (cst (fn* (n) (if (= n 0) nil (cst (- n 1))))) (cst 1))", \
    "nil", env)
  env = ASSERT_REP_ENV("(let* (f (fn* (n) (if (= n 0) 0 (g (- n 1)))) g (fn* (n) (f n))) (f 2))", \
    "0", env)

  env = ASSERT_REP_ENV("(def! DO (fn* (a) 7))", "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(DO 3)", "7", env)
  env = ASSERT_REP_ENV("(def! sumdown (fn* (N) (if (> N 0) (+ N (sumdown (- N 1))) 0)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(sumdown 6)", "21", env)
  env = ASSERT_REP_ENV("(def! fib (fn* (N) (if (= N 0) 1 (if (= N 1) 1 (+ (fib (- N 1)) (fib (- N 2)))))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(fib 4)", "5", env)

  env = ASSERT_REP_ENV("((fn* (& more) (count more)) 1 2 3)", "3", env)
  env = ASSERT_REP_ENV("((fn* (& more) (list? more)) 1 2 3)", "true", env)
  env = ASSERT_REP_ENV("((fn* (& more) (count more)))", "0", env)
  env = ASSERT_REP_ENV("((fn* (a & more) (count more)) 1 2 3)", "2", env)
  env = ASSERT_REP_ENV("((fn* (a & more) (count more)) 1)", "0", env)
  env = ASSERT_REP_ENV("((fn* (a & more) (list? more)) 1)", "true", env)

  env = ASSERT_REP_ENV("(fn*)", "fn*: expected 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(fn* (a))", "fn*: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(fn* 1 2)", "fn*: params must be list or vector", env)
  env = ASSERT_REP_ENV("(fn* (1) 2)", "fn*: params must be symbols", env)
  env = ASSERT_REP_ENV("(fn* (&) 2)", "fn*: params must be symbols", env)
  env = ASSERT_REP_ENV("(fn* (a & b c) 2)", "fn*: params must be symbols", env)
  env = ASSERT_REP_ENV("((fn* (a) a))", "fn*: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("((fn* () 1) 2)", "fn*: expected 0 arguments, got 1", env)
  env = ASSERT_REP_ENV("((fn* (a & more) a))", \
    "fn*: expected at least 1 arguments, got 0", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
