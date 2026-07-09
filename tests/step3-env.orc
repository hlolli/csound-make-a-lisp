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
    prints "STEP3 %s, Assertion success\n", input
  else
    prints "STEP3 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 3 def! and persistent REPL env\n"
  env:MalEnv = MalMkStep2Env()

  env = ASSERT_REP_ENV("(+ 1 2)", "3", env)
  env = ASSERT_REP_ENV("(def! x 3)", "3", env)
  env = ASSERT_REP_ENV("x", "3", env)
  env = ASSERT_REP_ENV("(def! x 4)", "4", env)
  env = ASSERT_REP_ENV("x", "4", env)
  env = ASSERT_REP_ENV("(def! y (+ 1 7))", "8", env)
  env = ASSERT_REP_ENV("y", "8", env)

  env = ASSERT_REP_ENV("(def! mynum 111)", "111", env)
  env = ASSERT_REP_ENV("(def! MYNUM 222)", "222", env)
  env = ASSERT_REP_ENV("mynum", "111", env)
  env = ASSERT_REP_ENV("MYNUM", "222", env)

  env = ASSERT_REP_ENV("(abc 1 2 3)", "'abc' not found", env)
  env = ASSERT_REP_ENV("(def! w 123)", "123", env)
  env = ASSERT_REP_ENV("(def! w (abc))", "'abc' not found", env)
  env = ASSERT_REP_ENV("w", "123", env)

  env = ASSERT_REP_ENV("(def!)", "def!: expected 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(def! 1 2)", "def!: first argument must be a symbol", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
