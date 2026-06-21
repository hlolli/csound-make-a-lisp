#include "types.orc"
#include "reader.orc"
#include "printer.orc"

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
  ;; prints "SRES9: %s\n", SRES9
endin

schedule("TEST", 0, 0)
event_i("e", 0, 0)
