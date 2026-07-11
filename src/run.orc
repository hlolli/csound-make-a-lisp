#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr MAL_SCRIPT
  ScommandLine:S[] argv

  if (lenarray(ScommandLine) == 0) then
    prints "Error: missing MAL script path\n"
    exitnow(1)
  else
    env:MalEnv = MalMkStepAEnv()
    scriptArgs:MalValue = MalStringArrayToList(ScommandLine, 1)
    env = MalEnvSet(env, "*ARGV*", scriptArgs)
    env = MalRefreshTopLevelFunctionClosures(env)

    scriptPath:S = ScommandLine[0]
    loadForm:MalValue = MalMkList2( \
      MalMkSymbol("load-file"), MalMkString(scriptPath))
    result:MalValue, env = EVAL_ENV(loadForm, env)

    if (result.type == $MAL_ERROR_TYPE) then
      prints "%s\n", result.string
      exitnow(1)
    else
      exitnow(0)
    endif
  endif
endin

schedule("MAL_SCRIPT", 0, 0)
