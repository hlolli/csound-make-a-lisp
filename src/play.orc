#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr MAL_PLAY
  ScommandLine:S[] argv

  if (lenarray(ScommandLine) == 0) ithen
    prints "Error: missing MAL music script path\n"
    exitnow(1)
  else
    env:MalEnv init MalMkCsoundEnv()
    scriptArgs:MalValue init MalStringArrayToList(ScommandLine, 1)
    env init MalEnvSet(env, "*ARGV*", scriptArgs)

    scriptPath:S init ScommandLine[0]
    loadForm:MalValue init MalMkList2( \
      MalMkSymbol("load-file"), MalMkString(scriptPath))
    scriptInputEnv:MalEnv init env
    result:MalValue, env = EVAL_ENV(loadForm, scriptInputEnv)

    if (result.type == $MAL_ERROR_TYPE) ithen
      prints "%s\n", result.string
      exitnow(1)
    endif
  endif
endin

schedule("MAL_PLAY", 0, 0)
