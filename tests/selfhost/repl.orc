#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr SELFHOST_REPL
  commandLine:S[] argv
  for index in [1 ... lenarray(commandLine) - 1] do
    accepted:i MalInputEnqueue commandLine[index], $MAL_INPUT_LINE
    if (accepted == 0) ithen
      prints "Error: self-host input queue is full\n"
      exitnow(1)
    endif
  od
  eofAccepted:i MalInputEnqueue "", $MAL_INPUT_EOF
  env:MalEnv init MalMkCsoundEnv()
  loadForm:MalValue init MalMkList2( \
    MalMkSymbol("load-file"), MalMkString(commandLine[0]))
  result:MalValue, nextEnv:MalEnv = EVAL_ENV(loadForm, env)
  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "%s\n", result.string
    exitnow(1)
  endif
  exitnow(0)
endin

schedule("SELFHOST_REPL", 0, 0)
