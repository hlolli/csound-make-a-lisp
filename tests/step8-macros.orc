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
    prints "STEP8 %s, Assertion success\n", input
  else
    prints "STEP8 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 8 macro definition and expansion\n"
  env:MalEnv = MalMkStep6Env()

  env = ASSERT_REP_ENV( \
    "(defmacro! unless (fn* (pred a b) `(if ~pred ~b ~a)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(macro? unless)", "true", env)
  env = ASSERT_REP_ENV("(unless false 7 missing)", "7", env)
  env = ASSERT_REP_ENV("(unless true missing 8)", "8", env)

  env = ASSERT_REP_ENV("(def! identity (fn* (x) x))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(defmacro! identity-macro identity)", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(macro? identity-macro)", "true", env)
  env = ASSERT_REP_ENV("(macro? identity)", "false", env)
  env = ASSERT_REP_ENV("(identity (+ 2 3))", "5", env)
  env = ASSERT_REP_ENV("(let* (a 123) (identity-macro a))", "123", env)

  env = ASSERT_REP_ENV( \
    "(defmacro! quote-argument (fn* (x) (list 'quote x)))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(quote-argument (+ 1 2))", "(+ 1 2)", env)

  env = ASSERT_REP_ENV("(defmacro!)", \
    "defmacro!: expected 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(defmacro! only-name)", \
    "defmacro!: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(defmacro! name (fn* () nil) nil)", \
    "defmacro!: expected 2 arguments, got 3", env)
  env = ASSERT_REP_ENV("(defmacro! 1 (fn* () nil))", \
    "defmacro!: first argument must be a symbol", env)
  env = ASSERT_REP_ENV("(defmacro! not-a-macro 1)", \
    "defmacro!: value must be a function", env)
  env = ASSERT_REP_ENV("not-a-macro", \
    "'not-a-macro' not found", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
