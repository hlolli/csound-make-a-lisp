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
    prints "STEP9 %s, Assertion success\n", input
  else
    prints "STEP9 %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual
    exitnow(1)
  endif

  xout updatedEnv
endop

opcode ASSERT_THROW(input:S, expectedMessage:S, expectedPayload:S, \
                    env:MalEnv):MalEnv
  ast:MalValue = read_str(input)
  thrown:MalValue, updatedEnv:MalEnv = EVAL_ENV(ast, env)
  payload:MalValue = MalErrorPayload(thrown)
  actualPayload:S = pr_str(payload)

  if (thrown.type == $MAL_ERROR_TYPE && \
      strcmp(thrown.string, expectedMessage) == 0 && \
      strcmp(actualPayload, expectedPayload) == 0) then
    prints "STEP9 %s payload, Assertion success\n", input
  else
    prints "STEP9 %s payload, Assertion failed: expected message '%s' and payload '%s', got message '%s' and payload '%s'\n", \
      input, expectedMessage, expectedPayload, thrown.string, actualPayload
    exitnow(1)
  endif

  xout updatedEnv
endop

instr TEST
  prints "Testing Step 9 throw and try/catch\n"
  env:MalEnv = MalMkStep9Env()

  env = ASSERT_REP_ENV("(throw \"uncaught\")", \
    "Error: \"uncaught\"", env)
  env = ASSERT_THROW("(throw \"err1\")", \
    "Error: \"err1\"", "\"err1\"", env)
  env = ASSERT_THROW("(throw (list 1 2 3))", \
    "Error: (1 2 3)", "(1 2 3)", env)
  env = ASSERT_THROW("(throw {:msg \"err2\"})", \
    "Error: {:msg \"err2\"}", "{:msg \"err2\"}", env)
  env = ASSERT_THROW("(throw nil)", "Error: nil", "nil", env)
  env = ASSERT_THROW("(cond true)", \
    "Error: \"odd number of forms to cond\"", \
    "\"odd number of forms to cond\"", env)

  env = ASSERT_REP_ENV("(throw)", \
    "throw: expected 1 arguments, got 0", env)
  env = ASSERT_REP_ENV("(throw 1 2)", \
    "throw: expected 1 arguments, got 2", env)

  env = ASSERT_REP_ENV("(try* 123)", "123", env)
  env = ASSERT_REP_ENV("(try* missing)", "'missing' not found", env)
  env = ASSERT_REP_ENV("(try* 123 (catch* e 456))", "123", env)
  env = ASSERT_REP_ENV("(try* missing (catch* e e))", \
    "\"'missing' not found\"", env)
  env = ASSERT_REP_ENV("(try* (nth () 1) (catch* e e))", \
    "\"nth: index out of range\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw \"my exception\") (catch* e e))", \
    "\"my exception\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw (list 1 2 3)) (catch* e e))", \
    "(1 2 3)", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw {:msg \"err2\"}) (catch* e e))", \
    "{:msg \"err2\"}", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw 7) (catch* e (+ e 1)))", "8", env)
  env = ASSERT_REP_ENV( \
    "((fn* (x) (try* (throw 2) (catch* e (+ x e)))) 3)", \
    "5", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (def! before-catch 9) (throw \"failed\")) (catch* e before-catch))", \
    "9", env)
  env = ASSERT_REP_ENV("before-catch", "9", env)

  env = ASSERT_REP_ENV("(def! attempts (atom 0))", "(atom 0)", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (swap! attempts + 1) (list 1)) (catch* e 0))", \
    "(1)", env)
  env = ASSERT_REP_ENV("(deref attempts)", "1", env)
  env = ASSERT_REP_ENV("(reset! attempts 0)", "0", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (swap! attempts + 1) (throw \"once\")) (catch* e (deref attempts)))", \
    "1", env)

  env = ASSERT_REP_ENV( \
    "(try* (try* (throw \"e1\") (catch* e (throw \"e2\"))) (catch* e e))", \
    "\"e2\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (do (try* \"t1\" (catch* e \"c1\")) (throw \"e1\")) (catch* e \"c2\"))", \
    "\"c2\"", env)
  env = ASSERT_REP_ENV( \
    "(try* (throw 7) (catch* caught caught))", "7", env)
  env = ASSERT_REP_ENV("caught", "'caught' not found", env)

  env = ASSERT_REP_ENV( \
    "(def! try-countdown (fn* (n) (if (= n 0) 0 (try* (try-countdown (- n 1))))))", \
    "#<function:fn*>", env)
  env = ASSERT_REP_ENV("(try-countdown 2000)", "0", env)

  env = ASSERT_REP_ENV("(try*)", \
    "try*: expected 1 or 2 arguments, got 0", env)
  env = ASSERT_REP_ENV("(try* 1 2 3)", \
    "try*: expected 1 or 2 arguments, got 3", env)
  env = ASSERT_REP_ENV("(try* missing nil)", \
    "try*: second argument must be (catch* symbol handler)", env)
  env = ASSERT_REP_ENV("(try* 1 (catch* e))", \
    "try*: second argument must be (catch* symbol handler)", env)
  env = ASSERT_REP_ENV("(try* 1 (catch* 2 3))", \
    "catch*: binding must be a symbol", env)
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
