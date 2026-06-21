#include "src/types.orc"
#include "src/constants.orc"
#include "src/utils.orc"
#include "src/reader.orc"
#include "src/printer.orc"

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

opcode REPL(input:S):void
  prints "AST: %s\n", PRINT(EVAL(READ(input)))
endop

instr TEST
  NumberAst:MalValue = READ("123")
  if (NumberAst.type == giNUMBER_TYPE && NumberAst.number == 123) then
    prints "READ number, Assertion success\n"
  else
    prints "READ number, Assertion failed: type=%d number=%f\n", NumberAst.type, NumberAst.number
    exitnow(1)
  endif

  NilAst:MalValue = READ("nil")
  TrueAst:MalValue = READ("true")
  FalseAst:MalValue = READ("false")
  SymbolAst:MalValue = READ("abc")
  if (NilAst.type == giNIL_TYPE && TrueAst.type == giTRUE_TYPE && \
      FalseAst.type == giFALSE_TYPE && SymbolAst.type == giSYMBOL_TYPE && \
      strcmp(SymbolAst.string, "abc") == 0) then
    prints "READ atoms, Assertion success\n"
  else
    prints "READ atoms, Assertion failed\n"
    exitnow(1)
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

  ;; SRES1 = REPL("\"string\" :kw1 \"string\" :kw2")
  ;; prints "SRES1: %s \n", SRES1
  ;; SRES2 = REPL(":keyword")
  ;; prints "SRES2: %s \n", SRES2
  ;; SRES3 = REPL("true")
  ;; prints "SRES3: %s \n", SRES3
  ;; SRES4 = REPL("123")
  ;; prints "SRES4: %s \n", SRES4
  ;; SRES5 = REPL("123 ")
  ;; prints "SRES5: '%s'\n", SRES5
  ;; SRES6 = REPL("abc")
  ;; prints "SRES6: '%s'\n", SRES6
  ;; SRES7 = REPL("abc")
  ;; prints "SRES7: '%s'\n", SRES7
  ;; SRES8 = REPL("abc ")
  ;; prints "SRES8: '%s'\n", SRES8
  REPL("'(123 456)")
  REPL("(nil true false abc)")
  ;; prints "SRES9: %s\n", SRES9
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
