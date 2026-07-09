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
  prints "Testing Step 4 if and do special forms\n"
  env:MalEnv = MalMkStep2Env()

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
  env = ASSERT_REP_ENV("(do (def! sequenced 1) (def! sequenced (+ sequenced 1)) sequenced)", \
    "2", env)
  env = ASSERT_REP_ENV("sequenced", "2", env)
  env = ASSERT_REP_ENV("(do (abc) (def! should-not-exist 1))", "'abc' not found", env)
  env = ASSERT_REP_ENV("should-not-exist", "'should-not-exist' not found", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
