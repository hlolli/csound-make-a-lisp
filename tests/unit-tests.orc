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
  prints "Testing builtin value representation\n"
  ASSERT_BUILTIN(MalMkBuiltin("core"), $MAL_BUILTIN_TYPE, "core", "#<builtin:core>")
  ASSERT_BUILTIN(MalMkBuiltinOperator("+"), $MAL_BUILTIN_OPERATOR_TYPE, "+", "#<builtin-operator:+>")
  ASSERT_BUILTIN(MalMkBuiltinOpcode("oscili"), $MAL_BUILTIN_OPCODE_TYPE, "oscili", "#<builtin-opcode:oscili>")
endin

schedule("TEST_ERRORS", 0, 0)
schedule("TEST_BUILTINS", 0, 0)
event_i("e", 0, 0)
