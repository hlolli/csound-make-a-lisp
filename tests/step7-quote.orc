#include "src/main.orc"

opcode REP_ENV(input:S, env:MalEnv):(S, MalEnv)
  ast:MalValue = read_str(input)
  currentEnv:MalEnv = env

  if (ast.type == $MAL_ERROR_TYPE) then
    result:S = ast.string
  else
    evaluated:MalValue, currentEnv = EVAL_ENV(ast, currentEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated.string
    else
      result = pr_str(evaluated)
    endif
  endif

  xout result, currentEnv
endop

opcode ASSERT_REP_ENV(input:S, expected:S, env:MalEnv):MalEnv
  actual:S, updatedEnv:MalEnv = REP_ENV(input, env)

  if (strcmp(actual, expected) == 0) then
    prints "STEP7 %s, Assertion success\n", input
  else
    prints "STEP7 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 7 immutable sequence builtins\n"
  env:MalEnv = MalMkStep6Env()

  env = ASSERT_REP_ENV("(cons 1 (list))", "(1)", env)
  env = ASSERT_REP_ENV("(cons 1 (list 2 3))", "(1 2 3)", env)
  env = ASSERT_REP_ENV("(cons (list 1) (list 2 3))", "((1) 2 3)", env)
  env = ASSERT_REP_ENV("(cons 1 [2 3])", "(1 2 3)", env)
  env = ASSERT_REP_ENV("(def! source (list 2 3))", "(2 3)", env)
  env = ASSERT_REP_ENV("(cons 1 source)", "(1 2 3)", env)
  env = ASSERT_REP_ENV("source", "(2 3)", env)

  env = ASSERT_REP_ENV("(concat)", "()", env)
  env = ASSERT_REP_ENV("(concat (list 1 2))", "(1 2)", env)
  env = ASSERT_REP_ENV("(concat (list 1 2) (list 3 4) (list 5 6))", \
    "(1 2 3 4 5 6)", env)
  env = ASSERT_REP_ENV("(concat [1 2] (list 3 4) [5 6])", \
    "(1 2 3 4 5 6)", env)
  env = ASSERT_REP_ENV("(concat (list 0 1 2 3 4 5 6) (list 7 8 9 10 11 12 13))", \
    "(0 1 2 3 4 5 6 7 8 9 10 11 12 13)", env)
  env = ASSERT_REP_ENV("(def! left (list 1 2))", "(1 2)", env)
  env = ASSERT_REP_ENV("(def! right [3 4])", "[3 4]", env)
  env = ASSERT_REP_ENV("(concat left right)", "(1 2 3 4)", env)
  env = ASSERT_REP_ENV("left", "(1 2)", env)
  env = ASSERT_REP_ENV("right", "[3 4]", env)

  env = ASSERT_REP_ENV("(vec (list))", "[]", env)
  env = ASSERT_REP_ENV("(vec (list 1 2))", "[1 2]", env)
  env = ASSERT_REP_ENV("(vec [1 2])", "[1 2]", env)
  env = ASSERT_REP_ENV("left", "(1 2)", env)

  env = ASSERT_REP_ENV("(cons 1)", \
    "cons: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(cons 1 2)", \
    "cons: second argument must be list or vector", env)
  env = ASSERT_REP_ENV("(concat (list 1) 2)", \
    "concat: expected list or vector arguments", env)
  env = ASSERT_REP_ENV("(vec 1)", \
    "vec: expected list or vector argument", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
