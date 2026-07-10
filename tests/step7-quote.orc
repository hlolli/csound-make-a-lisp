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

opcode ASSERT_QUASIQUOTE(input:S, expected:S):i
  ast:MalValue = read_str(input)
  transformed:MalValue = MalQuasiquote(ast)

  if (transformed.type == $MAL_ERROR_TYPE) then
    actual:S = transformed.string
  else
    actual:S = pr_str(transformed)
  endif

  if (strcmp(actual, expected) == 0) then
    prints "STEP7 quasiquote transform %s, Assertion success\n", input
    result:i = 1
  else
    prints "STEP7 quasiquote transform %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
    result = 0
  endif

  xout result
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

  env = ASSERT_REP_ENV("(nth (list 4 5 6) 1)", "5", env)
  env = ASSERT_REP_ENV("(nth [4 5 nil] 2)", "nil", env)
  env = ASSERT_REP_ENV("(first (list))", "nil", env)
  env = ASSERT_REP_ENV("(first nil)", "nil", env)
  env = ASSERT_REP_ENV("(first [4 5])", "4", env)
  env = ASSERT_REP_ENV("(rest (list))", "()", env)
  env = ASSERT_REP_ENV("(rest nil)", "()", env)
  env = ASSERT_REP_ENV("(rest [4 5 6])", "(5 6)", env)
  env = ASSERT_REP_ENV("(def! sequence-source [4 5 6])", "[4 5 6]", env)
  env = ASSERT_REP_ENV("(rest sequence-source)", "(5 6)", env)
  env = ASSERT_REP_ENV("sequence-source", "[4 5 6]", env)

  normalFunction:MalValue, env = EVAL_ENV(read_str("(fn* () 1)"), env)
  macroFunction:MalValue = MalFunctionAsMacro(normalFunction)
  env = MalEnvSet(env, "host-macro", macroFunction)
  env = ASSERT_REP_ENV("(macro? host-macro)", "true", env)
  env = ASSERT_REP_ENV("(macro? (fn* () 1))", "false", env)
  env = ASSERT_REP_ENV("(macro? +)", "false", env)

  env = ASSERT_REP_ENV("(cons 1)", \
    "cons: expected 2 arguments, got 1", env)
  env = ASSERT_REP_ENV("(cons 1 2)", \
    "cons: second argument must be list or vector", env)
  env = ASSERT_REP_ENV("(concat (list 1) 2)", \
    "concat: expected list or vector arguments", env)
  env = ASSERT_REP_ENV("(vec 1)", \
    "vec: expected list or vector argument", env)
  env = ASSERT_REP_ENV("(nth (list 1) 1)", \
    "nth: index out of range", env)
  env = ASSERT_REP_ENV("(nth (list 1) 0.5)", \
    "nth: index must be an integer", env)
  env = ASSERT_REP_ENV("(nth 1 0)", \
    "nth: first argument must be list or vector", env)
  env = ASSERT_REP_ENV("(first 1)", \
    "first: expected list, vector, or nil", env)
  env = ASSERT_REP_ENV("(rest 1)", \
    "rest: expected list, vector, or nil", env)
  env = ASSERT_REP_ENV("(macro?)", \
    "macro?: expected 1 arguments, got 0", env)

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

  env = ASSERT_REP_ENV("(quasiquote nil)", "nil", env)
  env = ASSERT_REP_ENV("(quasiquote undefined)", "undefined", env)
  env = ASSERT_REP_ENV("(quasiquote (1 2 (3 4)))", "(1 2 (3 4))", env)
  env = ASSERT_REP_ENV("(def! unquoted 8)", "8", env)
  env = ASSERT_REP_ENV("(quasiquote (1 (unquote unquoted) 3))", \
    "(1 8 3)", env)
  env = ASSERT_REP_ENV("(let* (local 9) (quasiquote (unquote local)))", \
    "9", env)
  env = ASSERT_REP_ENV("(def! spliced (quote (2 3)))", "(2 3)", env)
  env = ASSERT_REP_ENV("(quasiquote (1 (splice-unquote spliced) 4))", \
    "(1 2 3 4)", env)
  SlistShorthand:S = sprintf("%c(1 %cunquoted %c%cspliced 4)", \
    $MAL_BACKTICK_TOKEN, $MAL_TILDE_TOKEN, $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
  SvectorShorthand:S = sprintf("%c[1 %cunquoted %c%cspliced 4]", \
    $MAL_BACKTICK_TOKEN, $MAL_TILDE_TOKEN, $MAL_TILDE_TOKEN, $MAL_AT_TOKEN)
  env = ASSERT_REP_ENV(SlistShorthand, "(1 8 2 3 4)", env)
  env = ASSERT_REP_ENV(SvectorShorthand, "[1 8 2 3 4]", env)
  env = ASSERT_REP_ENV("(quasiquote)", \
    "quasiquote: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(quasiquote 1 2)", \
    "quasiquote: expected 1 arguments, got 2", env)
  env = ASSERT_REP_ENV("(quasiquote ((splice-unquote)))", \
    "splice-unquote: expected 1 arguments, got 0", env)

  transformCheck:i = ASSERT_QUASIQUOTE("nil", "nil")
  transformCheck = ASSERT_QUASIQUOTE("7", "7")
  transformCheck = ASSERT_QUASIQUOTE("a", "(quote a)")
  transformCheck = ASSERT_QUASIQUOTE("{\"a\" b}", "(quote {\"a\" b})")
  transformCheck = ASSERT_QUASIQUOTE("()", "()")
  transformCheck = ASSERT_QUASIQUOTE("(a 2)", \
    "(cons (quote a) (cons 2 ()))")
  transformCheck = ASSERT_QUASIQUOTE("(unquote a)", "a")
  transformCheck = ASSERT_QUASIQUOTE("(1 (unquote value) 3)", \
    "(cons 1 (cons value (cons 3 ())))")
  transformCheck = ASSERT_QUASIQUOTE("(1 (splice-unquote c) 3)", \
    "(cons 1 (concat c (cons 3 ())))")
  transformCheck = ASSERT_QUASIQUOTE("(1 (2 (unquote value)))", \
    "(cons 1 (cons (cons 2 (cons value ())) ()))")
  transformCheck = ASSERT_QUASIQUOTE("[]", "(vec ())")
  transformCheck = ASSERT_QUASIQUOTE("[a (unquote b)]", \
    "(vec (cons (quote a) (cons b ())))")
  transformCheck = ASSERT_QUASIQUOTE("[1 (splice-unquote c) 3]", \
    "(vec (cons 1 (concat c (cons 3 ()))))")
  transformCheck = ASSERT_QUASIQUOTE("(0 unquote)", \
    "(cons 0 (cons (quote unquote) ()))")
  transformCheck = ASSERT_QUASIQUOTE("(unquote)", \
    "unquote: expected 1 arguments, got 0")
  transformCheck = ASSERT_QUASIQUOTE("((splice-unquote))", \
    "splice-unquote: expected 1 arguments, got 0")
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
