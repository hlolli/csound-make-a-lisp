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
    prints "STEP5 %s, Assertion success\n", input
  else
    prints "STEP5 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 5 tail call optimization\n"
  env:MalEnv = MalMkStep2Env()

  env = ASSERT_REP_ENV("(def! sum2 (fn* (n acc) (if (= n 0) acc (sum2 (- n 1) (+ n acc)))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(sum2 10 0)", "55", env)
  env = ASSERT_REP_ENV("(sum2 10000 0)", "50005000", env)

  env = ASSERT_REP_ENV("(def! foo (fn* (n) (if (= n 0) 0 (bar (- n 1)))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(def! bar (fn* (n) (if (= n 0) 0 (foo (- n 1)))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(foo 10000)", "0", env)

  env = ASSERT_REP_ENV("(let* (loop (fn* (n) (if (= n 0) 7 (loop (- n 1))))) (loop 10000))", \
    "7", env)
  env = ASSERT_REP_ENV("(do (def! done-value 3) (sum2 10000 0))", \
    "50005000", env)
  env = ASSERT_REP_ENV("done-value", "3", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
