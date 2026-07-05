#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop


opcode EVAL(ast:MalValue):MalValue
  xout ast
endop

opcode PRINT(ast:MalValue):S
  Sprintout = pr_str(ast)
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
  ASSERT_READ_ERROR("}", "unexpected '}'")
  ASSERT_READ_ERROR("{]", "unexpected ']'")
  ASSERT_READ_ERROR("')", "unexpected ')'")
  ASSERT_READ_ERROR("`]", "unexpected ']'")
  ASSERT_READ_ERROR("^:meta }", "unexpected '}'")
  ASSERT_READ_ERROR("\"unterminated", "expected '\"', got EOF")
endin

schedule("TEST_ERRORS", 0, 0)
event_i("e", 0, 0)
