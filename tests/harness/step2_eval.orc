#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop

opcode EVAL(ast:MalValue):MalValue
  xout ast
endop

opcode PRINT(ast:MalValue):S
  xout pr_str_with_readability(ast, 1)
endop

instr RUN
  Sinput strget 1
  tokens:MalTokens = tokenize(Sinput)

  if (tokens.length > 0) then
    ast:MalValue = READ(Sinput)

    if (ast.type == $MAL_ERROR_TYPE) then
      prints "Error: %s\n", ast.string
    else
      prints "%s\n", PRINT(EVAL(ast))
    endif
  endif

  exitnow(0)
endin

schedule("RUN", 0, 0)
