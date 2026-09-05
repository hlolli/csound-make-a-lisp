;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include "src/main.orc"

opcode READ(input:S):MalValue
  xout read_str(input)
endop

opcode PRINT(ast:MalValue):S
  xout pr_str_with_readability(ast, 1)
endop

instr RUN
  Sinput strget 1
  env:MalEnv = MalMkStep2Env()
  tokens:MalTokens = tokenize(Sinput)

  if (tokens.length > 0) then
    ast:MalValue = READ(Sinput)

    if (ast.type == $MAL_ERROR_TYPE) then
      prints "Error: %s\n", ast.string
    else
      evaluated:MalValue = EVAL(ast, env)

      if (evaluated.type == $MAL_ERROR_TYPE) then
        prints "Error: %s\n", evaluated.string
      else
        prints "%s\n", PRINT(evaluated)
      endif
    endif
  endif

  exitnow(0)
endin

schedule("RUN", 0, 0)
