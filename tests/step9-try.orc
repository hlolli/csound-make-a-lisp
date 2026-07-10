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
  prints "Testing Step 9 throw builtin\n"
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
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
