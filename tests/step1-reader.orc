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

opcode REPL(input:S):void
  prints "AST: %s\n", REP(input)
endop

opcode ASSERT_REP(input:S, expected:S):void
  actual:S = REP(input)
  if (strcmp(actual, expected) == 0) then
    prints "REPL %s, Assertion success\n", input
  else
    prints "REPL %s, Assertion failed: expected '%s', got '%s'\n", input, expected, actual
    exitnow(1)
  endif
endop

instr TEST
  prints "Testing basic reader functionality\n"
  NumberAst:MalValue = READ("123")
  if (NumberAst.type == giNUMBER_TYPE && NumberAst.number == 123) then
    prints "READ number, Assertion success\n"
  else
    prints "READ number, Assertion failed: type=%d number=%f\n", NumberAst.type, NumberAst.number
    exitnow(1)
  endif

  NilAst:MalValue = READ("nil")
  if (NilAst.type == giNIL_TYPE) then
    prints "READ nil, Assertion success\n"
  else
    prints "READ nil, Assertion failed: expected type=%d, got type=%d\n", \
      giNIL_TYPE, NilAst.type
    exitnow(1)
  endif

  TrueAst:MalValue = READ("true")
  if (TrueAst.type == giTRUE_TYPE) then
    prints "READ true, Assertion success\n"
  else
    prints "READ true, Assertion failed: expected type=%d, got type=%d\n", \
      giTRUE_TYPE, TrueAst.type
    exitnow(1)
  endif

  FalseAst:MalValue = READ("false")
  if (FalseAst.type == giFALSE_TYPE) then
    prints "READ false, Assertion success\n"
  else
    prints "READ false, Assertion failed: expected type=%d, got type=%d\n", \
      giFALSE_TYPE, FalseAst.type
    exitnow(1)
  endif

  SymbolAst:MalValue = READ("abc")
  if (SymbolAst.type != giSYMBOL_TYPE) then
    prints "READ symbol type, Assertion failed: expected type=%d, got type=%d\n", \
      giSYMBOL_TYPE, SymbolAst.type
    exitnow(1)
  elseif (strcmp(SymbolAst.string, "abc") != 0) then
    prints "READ symbol string, Assertion failed: expected 'abc', got '%s'\n", \
      SymbolAst.string
    exitnow(1)
  else
    prints "READ symbol, Assertion success\n"
  endif

  QuoteAst:MalValue = READ("'(123 456)")
  if (QuoteAst.type == giQUOTE_TYPE && QuoteAst.length == 1) then
    ListAst:MalValue = QuoteAst.list[0]
    FirstAst:MalValue = ListAst.list[0]
    SecondAst:MalValue = ListAst.list[1]
    if (ListAst.type == giLIST_TYPE && ListAst.length == 2 && \
        FirstAst.number == 123 && SecondAst.number == 456) then
      prints "READ quote/list, Assertion success\n"
    else
      prints "READ quote/list, Assertion failed\n"
      exitnow(1)
    endif
  else
    prints "READ quote/list, Assertion failed\n"
    exitnow(1)
  endif

  ;; Not ready yet: strings and keywords need dedicated reader support.
  ;; ASSERT_REP("\"string\" :kw1 \"string\" :kw2", "\"string\" :kw1 \"string\" :kw2")
  ;; ASSERT_REP(":keyword", ":keyword")

  ASSERT_REP("true", "true")
  ASSERT_REP("123", "123.00000")
  ASSERT_REP("123 ", "123.00000")
  ASSERT_REP("abc", "abc")
  ASSERT_REP("abc", "abc")
  ASSERT_REP("abc ", "abc")
  REPL("'(123 456)")
  REPL("(nil true false abc)")
  ;; prints "SRES9: %s\n", SRES9
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
