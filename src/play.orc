#include "src/main.orc"

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1

instr MAL_PLAY
  ScommandLine:S[] argv

  if (lenarray(ScommandLine) == 0) then
    prints "Error: missing MAL music script path\n"
    exitnow(1)
  else
    env:MalEnv = MalMkCsoundEnv()
    scriptArgs:MalValue = MalStringArrayToList(ScommandLine, 1)
    env = MalEnvSet(env, "*ARGV*", scriptArgs)

    scriptPath:S = ScommandLine[0]
    loadForm:MalValue = MalMkList2( \
      MalMkSymbol("load-file"), MalMkString(scriptPath))
    scriptInputEnv:MalEnv = env
    result:MalValue, env = EVAL_ENV(loadForm, scriptInputEnv)

    if (result.type == $MAL_ERROR_TYPE) then
      prints "%s\n", result.string
      exitnow(1)
    endif
  endif
endin

schedule("MAL_PLAY", 0, 0)
