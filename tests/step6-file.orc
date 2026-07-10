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
    prints "STEP6 %s, Assertion success\n", input
  else
    prints "STEP6 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 6 file and reader builtins\n"
  env:MalEnv = MalMkStep2Env()

  env = ASSERT_REP_ENV("(read-string \"(+ 2 3)\")", "(+ 2 3)", env)
  env = ASSERT_REP_ENV("(read-string \"(1 2 (3 4) nil)\")", \
    "(1 2 (3 4) nil)", env)
  env = ASSERT_REP_ENV("(= nil (read-string \"nil\"))", "true", env)
  env = ASSERT_REP_ENV("(read-string \"7 ;; comment\")", "7", env)
  env = ASSERT_REP_ENV("(str \"(do \" \"(+ 1 2)\" \"\\nnil)\")", \
    "\"(do (+ 1 2)\\nnil)\"", env)
  env = ASSERT_REP_ENV("(slurp \"mal/tests/test.txt\")", \
    "\"A line of text\\n\"", env)
  env = ASSERT_REP_ENV("(slurp \"mal/tests/test.txt\")", \
    "\"A line of text\\n\"", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
