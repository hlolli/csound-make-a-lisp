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
    prints "STEPA %s, Assertion success\n", input
  else
    prints "STEPA %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step A core functions\n"
  env:MalEnv = MalMkStepAEnv()
  env = MalEnvSet(env, "host-opcode", MalMkBuiltinOpcode("oscili"))

  env = ASSERT_REP_ENV("*host-language*", "\"Csound7\"", env)

  env = ASSERT_REP_ENV( \
    "(def! ordinary-function (fn* (x) x))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV( \
    "(defmacro! copied-macro ordinary-function)", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(fn? ordinary-function)", "true", env)
  env = ASSERT_REP_ENV("(macro? ordinary-function)", "false", env)
  env = ASSERT_REP_ENV("(fn? copied-macro)", "false", env)
  env = ASSERT_REP_ENV("(macro? copied-macro)", "true", env)

  env = ASSERT_REP_ENV("(def! original [1 2 3])", "[1 2 3]", env)
  env = ASSERT_REP_ENV( \
    "(def! decorated (with-meta original {:source \"test\"}))", \
    "[1 2 3]", env)
  env = ASSERT_REP_ENV("(meta original)", "nil", env)
  env = ASSERT_REP_ENV( \
    "(meta decorated)", "{:source \"test\"}", env)
  env = ASSERT_REP_ENV( \
    "(meta ^{:reader true} [1 2])", "{:reader true}", env)
  env = ASSERT_REP_ENV("(= original decorated)", "true", env)
  env = ASSERT_REP_ENV( \
    "(meta (with-meta decorated {:source \"new\"}))", \
    "{:source \"new\"}", env)
  env = ASSERT_REP_ENV( \
    "(meta decorated)", "{:source \"test\"}", env)

  env = ASSERT_REP_ENV( \
    "(def! add-meta (let* (x 7) (with-meta (fn* (y) (+ x y)) {:kind \"closure\"})))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(add-meta 8)", "15", env)
  env = ASSERT_REP_ENV( \
    "(meta add-meta)", "{:kind \"closure\"}", env)
  env = ASSERT_REP_ENV("(fn? add-meta)", "true", env)
  env = ASSERT_REP_ENV("(fn? cond)", "false", env)
  env = ASSERT_REP_ENV( \
    "(fn? (with-meta cond {:kind \"macro\"}))", "false", env)
  env = ASSERT_REP_ENV( \
    "(macro? (with-meta cond {:kind \"macro\"}))", "true", env)

  env = ASSERT_REP_ENV( \
    "(def! plus-with-meta (with-meta + {:native true}))", \
    "#<builtin-operator:+>", env)
  env = ASSERT_REP_ENV("(fn? plus-with-meta)", "true", env)
  env = ASSERT_REP_ENV("(meta plus-with-meta)", "{:native true}", env)
  env = ASSERT_REP_ENV("(meta +)", "nil", env)
  env = ASSERT_REP_ENV("(plus-with-meta 2 3)", "5", env)

  env = ASSERT_REP_ENV("(string? \"\")", "true", env)
  env = ASSERT_REP_ENV("(string? :abc)", "false", env)
  env = ASSERT_REP_ENV("(number? -1)", "true", env)
  env = ASSERT_REP_ENV("(number? \"1\")", "false", env)
  env = ASSERT_REP_ENV("(fn? +)", "true", env)
  env = ASSERT_REP_ENV("(fn? list?)", "true", env)
  env = ASSERT_REP_ENV("(fn? host-opcode)", "true", env)
  env = ASSERT_REP_ENV("(fn? (fn* (x) x))", "true", env)
  env = ASSERT_REP_ENV("(fn? \"+\")", "false", env)

  env = ASSERT_REP_ENV("(seq \"abc\")", "(\"a\" \"b\" \"c\")", env)
  env = ASSERT_REP_ENV( \
    "(apply str (seq \"this is a test\"))", \
    "\"this is a test\"", env)
  env = ASSERT_REP_ENV("(seq '(2 3 4))", "(2 3 4)", env)
  env = ASSERT_REP_ENV("(seq [2 3 4])", "(2 3 4)", env)
  env = ASSERT_REP_ENV("(seq \"\")", "nil", env)
  env = ASSERT_REP_ENV("(seq '())", "nil", env)
  env = ASSERT_REP_ENV("(seq [])", "nil", env)
  env = ASSERT_REP_ENV("(seq nil)", "nil", env)

  env = ASSERT_REP_ENV("(def! source-list (list 2 3))", "(2 3)", env)
  env = ASSERT_REP_ENV( \
    "(conj source-list 4 5 6)", "(6 5 4 2 3)", env)
  env = ASSERT_REP_ENV("source-list", "(2 3)", env)
  env = ASSERT_REP_ENV("(def! source-vector [2 3])", "[2 3]", env)
  env = ASSERT_REP_ENV( \
    "(conj source-vector 4 5 6)", "[2 3 4 5 6]", env)
  env = ASSERT_REP_ENV("source-vector", "[2 3]", env)
  env = ASSERT_REP_ENV("(conj (list 1) (list 2 3))", \
    "((2 3) 1)", env)
  env = ASSERT_REP_ENV("(conj [1] [2 3])", "[1 [2 3]]", env)

  env = ASSERT_REP_ENV("(number? (time-ms))", "true", env)
  env = ASSERT_REP_ENV("(> (time-ms) 0)", "true", env)
  env = ASSERT_REP_ENV("(println)", "nil", env)
  env = ASSERT_REP_ENV( \
    "(println \"hello\" \"MAL\" [1 2])", "nil", env)

  env = ASSERT_REP_ENV("(meta)", \
    "meta: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(with-meta [])", \
    "with-meta: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(seq {})", \
    "seq: expected list, vector, string, or nil", env)
  env = ASSERT_REP_ENV("(conj [])", \
    "conj: expected at least 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(conj {} 1)", \
    "conj: first argument must be list or vector", env)
  env = ASSERT_REP_ENV("(time-ms 1)", \
    "time-ms: expected 0 arguments, got 1", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
