#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop


opcode EVAL(ast:MalValue):MalValue
  xout ast
endop

opcode PRINT(ast:MalValue):S
  Sprintout = pr_str_with_readability(ast, 1)
  xout Sprintout
endop

opcode REP(input:S):S
  xout PRINT(EVAL(READ(input)))
endop

opcode ASSERT_READ_ERROR(input:S, expected:S):void
  actual:MalValue = READ(input)

  if (actual.type != $MAL_ERROR_TYPE) then
    prints "READ error %s, Assertion failed: expected type=%d, got type=%d\n", \
      input, $MAL_ERROR_TYPE, actual.type
    exitnow(1)
  elseif (strcmp(actual.string, expected) != 0) then
    prints "READ error %s, Assertion failed: expected '%s', got '%s'\n", \
      input, expected, actual.string
    exitnow(1)
  else
    prints "READ error %s, Assertion success\n", input
  endif
endop

opcode ASSERT_BUILTIN(value:MalValue, expectedType:i, expectedName:S, expectedPrint:S):void
  if (value.type != expectedType) then
    prints "BUILTIN %s, Assertion failed: expected type=%d, got type=%d\n", \
      expectedName, expectedType, value.type
    exitnow(1)
  elseif (strcmp(value.string, expectedName) != 0) then
    prints "BUILTIN %s, Assertion failed: expected name='%s', got '%s'\n", \
      expectedName, expectedName, value.string
    exitnow(1)
  elseif (strcmp(pr_str(value), expectedPrint) != 0) then
    prints "BUILTIN %s, Assertion failed: expected print='%s', got '%s'\n", \
      expectedName, expectedPrint, pr_str(value)
    exitnow(1)
  else
    prints "BUILTIN %s, Assertion success\n", expectedName
  endif
endop

opcode ASSERT_ENV_VALUE(env:MalEnv, key:S, expectedType:i, expectedName:S):void
  value:MalValue = MalEnvGet(env, key)

  if (value.type != expectedType) then
    prints "ENV %s, Assertion failed: expected type=%d, got type=%d\n", \
      key, expectedType, value.type
    exitnow(1)
  elseif (strcmp(value.string, expectedName) != 0) then
    prints "ENV %s, Assertion failed: expected name='%s', got '%s'\n", \
      key, expectedName, value.string
    exitnow(1)
  else
    prints "ENV %s, Assertion success\n", key
  endif
endop

opcode ASSERT_ENV_ERROR(env:MalEnv, key:S, expected:S):void
  value:MalValue = MalEnvGet(env, key)

  if (value.type != $MAL_ERROR_TYPE) then
    prints "ENV missing %s, Assertion failed: expected type=%d, got type=%d\n", \
      key, $MAL_ERROR_TYPE, value.type
    exitnow(1)
  elseif (strcmp(value.string, expected) != 0) then
    prints "ENV missing %s, Assertion failed: expected '%s', got '%s'\n", \
      key, expected, value.string
    exitnow(1)
  else
    prints "ENV missing %s, Assertion success\n", key
  endif
endop

instr TEST_ERRORS
  prints "Testing error handling\n"
  ASSERT_READ_ERROR("(", "expected ')', got EOF")
  ASSERT_READ_ERROR("(123", "expected ')', got EOF")
  ASSERT_READ_ERROR("(123 456", "expected ')', got EOF")
  ASSERT_READ_ERROR("(123 (456)", "expected ')', got EOF")
  ASSERT_READ_ERROR(")", "unexpected ')'")
  ASSERT_READ_ERROR("(]", "unexpected ']'")
  ASSERT_READ_ERROR("(123 }", "unexpected '}'")
  ASSERT_READ_ERROR("[", "expected ']', got EOF")
  ASSERT_READ_ERROR("[123", "expected ']', got EOF")
  ASSERT_READ_ERROR("[123 456", "expected ']', got EOF")
  ASSERT_READ_ERROR("[123 [456]", "expected ']', got EOF")
  ASSERT_READ_ERROR("]", "unexpected ']'")
  ASSERT_READ_ERROR("[)", "unexpected ')'")
  ASSERT_READ_ERROR("{", "expected '}', got EOF")
  ASSERT_READ_ERROR("{\"a\" 1", "expected '}', got EOF")
  ASSERT_READ_ERROR("{:a {:b 2}", "expected '}', got EOF")
  ASSERT_READ_ERROR("{:a}", "expected hash-map value, got end of map")
  ASSERT_READ_ERROR("{:a {:b}}", "expected hash-map value, got end of map")
  ASSERT_READ_ERROR("}", "unexpected '}'")
  ASSERT_READ_ERROR("{]", "unexpected ']'")
  ASSERT_READ_ERROR("')", "unexpected ')'")
  ASSERT_READ_ERROR("`]", "unexpected ']'")
  ASSERT_READ_ERROR("^:meta }", "unexpected '}'")
  ASSERT_READ_ERROR("\"unterminated", "expected '\"', got EOF")
  Squote = sprintf("%c", $MAL_DOUBLE_QUOTE_TOKEN)
  Sbackslash = sprintf("%c", $MAL_BACKSLASH_TOKEN)
  ASSERT_READ_ERROR(Squote, "expected '\"', got EOF")
  ASSERT_READ_ERROR(strcat(Squote, Sbackslash), "expected '\"', got EOF")
  ASSERT_READ_ERROR(strcat(strcat(Squote, Sbackslash), Squote), "expected '\"', got EOF")
endin

instr TEST_BUILTINS
  prints "Testing callable value representation\n"
  ASSERT_BUILTIN(MalMkBuiltin("core"), $MAL_BUILTIN_TYPE, "core", "#<builtin:core>")
  ASSERT_BUILTIN(MalMkBuiltinOperator("+"), $MAL_BUILTIN_OPERATOR_TYPE, "+", "#<builtin-operator:+>")
  ASSERT_BUILTIN(MalMkBuiltinOpcode("oscili"), $MAL_BUILTIN_OPCODE_TYPE, "oscili", "#<builtin-opcode:oscili>")

  env:MalEnv = MalMkEnv()
  env = MalEnvSet(env, "captured", MalMkSymbol("captured"))
  params:MalValue = MalMkList1(MalMkSymbol("x"))
  body:MalValue = MalMkSymbol("x")
  closure:MalEnv[] init 1
  closure[0] = env
  functionValue:MalValue = MalMkFunctionWithEnv(params, body, closure)
  macroValue:MalValue = MalFunctionAsMacro(functionValue)
  storedParams:MalValue = functionValue.list[0]
  storedParam:MalValue = storedParams.list[0]
  storedBody:MalValue = functionValue.list[1]
  functionEnv:MalEnv[] = functionValue.env
  capturedEnv:MalEnv = functionEnv[0]
  captured:MalValue = MalEnvGet(capturedEnv, "captured")
  SfunctionPrint = pr_str(functionValue)
  SexpectedFunctionPrint = sprintf("%c<function:fn*>", 35)

  if (functionValue.type != $MAL_FUNCTION_TYPE) then
    prints "FUNCTION, Assertion failed: expected type=%d, got type=%d\n", \
      $MAL_FUNCTION_TYPE, functionValue.type
    exitnow(1)
  endif

  if (functionValue.isMacro != 0 || MalIsMacro(functionValue) != 0) then
    prints "FUNCTION, Assertion failed: normal function marked as macro\n"
    exitnow(1)
  endif

  if (macroValue.type != $MAL_FUNCTION_TYPE || macroValue.isMacro != 1 || \
      MalIsMacro(macroValue) != 1) then
    prints "FUNCTION, Assertion failed: macro type=%d flag=%d predicate=%d\n", \
      macroValue.type, macroValue.isMacro, MalIsMacro(macroValue)
    exitnow(1)
  endif

  if (macroValue.length != functionValue.length || \
      lenarray(macroValue.env) != lenarray(functionValue.env)) then
    prints "FUNCTION, Assertion failed: macro marking changed function data\n"
    exitnow(1)
  endif

  if (MalIsMacro(MalMkBuiltin("not-a-macro")) != 0) then
    prints "FUNCTION, Assertion failed: builtin reported as macro\n"
    exitnow(1)
  endif

  if (functionValue.length != 2) then
    prints "FUNCTION, Assertion failed: expected length=2, got length=%d\n", \
      functionValue.length
    exitnow(1)
  endif

  if (storedParams.type != $MAL_LIST_TYPE || storedParams.length != 1) then
    prints "FUNCTION, Assertion failed: params not stored correctly\n"
    exitnow(1)
  endif

  if (storedParam.type != $MAL_SYMBOL_TYPE || strcmp(storedParam.string, "x") != 0) then
    prints "FUNCTION, Assertion failed: param symbol not stored correctly\n"
    exitnow(1)
  endif

  if (storedBody.type != $MAL_SYMBOL_TYPE || strcmp(storedBody.string, "x") != 0) then
    prints "FUNCTION, Assertion failed: body not stored correctly\n"
    exitnow(1)
  endif

  if (lenarray(functionEnv) != 1) then
    prints "FUNCTION, Assertion failed: closure env not stored correctly\n"
    exitnow(1)
  endif

  if (captured.type != $MAL_SYMBOL_TYPE || strcmp(captured.string, "captured") != 0) then
    prints "FUNCTION, Assertion failed: captured binding not available\n"
    exitnow(1)
  endif

  if (strcmp(SfunctionPrint, SexpectedFunctionPrint) != 0) then
    prints "FUNCTION, Assertion failed: expected function print, got '%s'\n", \
      SfunctionPrint
    exitnow(1)
  endif

  prints "FUNCTION, Assertion success\n"
endin

instr TEST_ENV
  prints "Testing environment map\n"
  env:MalEnv = MalMkEnv()
  env = MalEnvSet(env, "x", MalMkBuiltin("first"))
  ASSERT_ENV_VALUE(env, "x", $MAL_BUILTIN_TYPE, "first")

  env = MalEnvSet(env, "x", MalMkBuiltin("second"))
  ASSERT_ENV_VALUE(env, "x", $MAL_BUILTIN_TYPE, "second")
  ASSERT_ENV_ERROR(env, "missing", "'missing' not found")

  child:MalEnv = MalMkEnvWithOuter(env)
  ASSERT_ENV_VALUE(child, "x", $MAL_BUILTIN_TYPE, "second")

  child = MalEnvSet(child, "x", MalMkBuiltin("child"))
  ASSERT_ENV_VALUE(child, "x", $MAL_BUILTIN_TYPE, "child")
  ASSERT_ENV_VALUE(env, "x", $MAL_BUILTIN_TYPE, "second")
  ASSERT_ENV_ERROR(child, "missing", "'missing' not found")

  step2Env:MalEnv = MalMkStep2Env()
  ASSERT_ENV_VALUE(step2Env, "+", $MAL_BUILTIN_OPERATOR_TYPE, "+")
  ASSERT_ENV_VALUE(step2Env, "-", $MAL_BUILTIN_OPERATOR_TYPE, "-")
  ASSERT_ENV_VALUE(step2Env, "*", $MAL_BUILTIN_OPERATOR_TYPE, "*")
  ASSERT_ENV_VALUE(step2Env, "/", $MAL_BUILTIN_OPERATOR_TYPE, "/")
endin

instr TEST_METADATA
  prints "Testing metadata storage\n"

  value:MalValue = MalMkList1(MalMkSymbol("value"))
  metadataValue:MalValue = MalMkKeyword("tag")
  valueWithMeta:MalValue = MalWithMeta(value, metadataValue)
  storedMetadata:MalValue = MalMeta(valueWithMeta)
  originalMetadata:MalValue = MalMeta(value)

  if (lenarray(value.metadata) != 0 || \
      originalMetadata.type != $MAL_NIL_TYPE) then
    prints "METADATA, Assertion failed: new values should have no metadata\n"
    exitnow(1)
  elseif (lenarray(valueWithMeta.metadata) != 1 || \
          storedMetadata.type != $MAL_KEYWORD_TYPE || \
          strcmp(storedMetadata.string, "tag") != 0) then
    prints "METADATA, Assertion failed: attached metadata was not preserved\n"
    exitnow(1)
  elseif (valueWithMeta.type != value.type || \
          valueWithMeta.length != value.length || \
          strcmp(valueWithMeta.list[0].string, value.list[0].string) != 0) then
    prints "METADATA, Assertion failed: with-meta changed the value\n"
    exitnow(1)
  elseif (MalEquals(value, valueWithMeta) != 1) then
    prints "METADATA, Assertion failed: equality considered metadata\n"
    exitnow(1)
  endif

  env:MalEnv = MalMkEnv()
  env = MalEnvSet(env, "captured", MalMkSymbol("binding"))
  closure:MalEnv[] init 1
  closure[0] = env
  functionValue:MalValue = MalMkFunctionWithEnv( \
    MalMkList1(MalMkSymbol("x")), MalMkSymbol("x"), closure)
  macroValue:MalValue = MalFunctionAsMacro(functionValue)
  macroWithMeta:MalValue = MalWithMeta(macroValue, metadataValue)
  macroEnv:MalEnv[] = macroWithMeta.env
  captured:MalValue = MalEnvGet(macroEnv[0], "captured")

  if (macroWithMeta.type != $MAL_FUNCTION_TYPE || \
      macroWithMeta.isMacro != 1 || macroWithMeta.length != 2 || \
      lenarray(macroEnv) != 1 || captured.type != $MAL_SYMBOL_TYPE || \
      strcmp(captured.string, "binding") != 0) then
    prints "METADATA, Assertion failed: function data was not preserved\n"
    exitnow(1)
  endif

  readerTokens:S[] init 1
  readerTokens[0] = "done"
  reader:MalReader init "done", 0, readerTokens, 1, 1
  readResult:MalReadResult = MalMkReadResult(macroWithMeta, reader)
  roundTrip:MalValue = MalReadResultValue(readResult)
  roundTripMetadata:MalValue = MalMeta(roundTrip)

  if (roundTrip.isMacro != 1 || lenarray(roundTrip.env) != 1 || \
      roundTripMetadata.type != $MAL_KEYWORD_TYPE || \
      strcmp(roundTripMetadata.string, "tag") != 0) then
    prints "METADATA, Assertion failed: reader result lost value data\n"
    exitnow(1)
  endif

  prints "METADATA, Assertion success\n"
endin

schedule("TEST_ERRORS", 0, 0)
schedule("TEST_BUILTINS", 0, 0)
schedule("TEST_ENV", 0, 0)
schedule("TEST_METADATA", 0, 0)
event_i("e", 0, 0)
