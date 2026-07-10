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

opcode ASSERT_FORM(input:S, name:S, expected:i):i
  ast:MalValue = read_str(input)
  actual:i = MalIsForm(ast, name)

  if (actual == expected) then
    prints "STEP7 MalIsForm %s as %s, Assertion success\n", input, name
  else
    prints "STEP7 MalIsForm %s as %s, Assertion failed: expected %d, got %d\n", \
      input, name, expected, actual
    exitnow(1)
  endif

  xout actual
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

  formCheck:i = ASSERT_FORM("(unquote value)", "unquote", 1)
  formCheck = ASSERT_FORM("(splice-unquote values)", "splice-unquote", 1)
  formCheck = ASSERT_FORM("(quote value)", "unquote", 0)
  formCheck = ASSERT_FORM("[unquote value]", "unquote", 0)
  formCheck = ASSERT_FORM("()", "unquote", 0)
  formCheck = ASSERT_FORM("unquote", "unquote", 0)
  formCheck = ASSERT_FORM("(1 value)", "unquote", 0)

  env = ASSERT_REP_ENV("(quote 7)", "7", env)
  env = ASSERT_REP_ENV("(quote abc)", "abc", env)
  env = ASSERT_REP_ENV("(quote (1 2 3))", "(1 2 3)", env)
  env = ASSERT_REP_ENV("(quote (1 2 (3 4)))", "(1 2 (3 4))", env)
  env = ASSERT_REP_ENV("(quote [1 abc])", "[1 abc]", env)
  env = ASSERT_REP_ENV("(quote {\"a\" abc})", "{\"a\" abc}", env)
  env = ASSERT_REP_ENV("(def! quoted (quote (+ 1 2)))", "(+ 1 2)", env)
  env = ASSERT_REP_ENV("quoted", "(+ 1 2)", env)
  env = ASSERT_REP_ENV("'abc", "abc", env)
  env = ASSERT_REP_ENV("'(1 2 3)", "(1 2 3)", env)
  env = ASSERT_REP_ENV("(quote)", \
    "quote: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(quote 1 2)", \
    "quote: expected 1 arguments, got 2", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
