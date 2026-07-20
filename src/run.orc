#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr MAL_SCRIPT
  ScommandLine:S[] argv

  if (lenarray(ScommandLine) == 0) ithen
    prints "Error: missing MAL script path\n"
    exitnow(1)
  else
    env:MalEnv init MalMkCsoundEnv()
    scriptArgs:MalValue init MalStringArrayToList(ScommandLine, 1)
    env init MalEnvSet(env, "*ARGV*", scriptArgs)
    env init MalRefreshTopLevelFunctionClosures(env)

    scriptPath:S init ScommandLine[0]
    loadForm:MalValue init MalMkList2( \
      MalMkSymbol("load-file"), MalMkString(scriptPath))
    scriptInputEnv:MalEnv init env
    result:MalValue, env = EVAL_ENV(loadForm, scriptInputEnv)

    if (result.type == $MAL_ERROR_TYPE) ithen
      prints "%s\n", result.string
      exitnow(1)
    else
      exitnow(0)
    endif
  endif
endin

schedule("MAL_SCRIPT", 0, 0)
