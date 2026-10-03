<CsoundSynthesizer>
<CsOptions>
-odac -d -m0
</CsOptions>
<CsInstruments>
sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

#include "mal.inc"

malLiveEnv@global:MalEnv init MalMkCsoundEnv()

opcode LispEval(source:S):i
  value:MalValue, nextEnv:MalEnv = MalEvalFormsEnv(source, malLiveEnv)
  malLiveEnv = nextEnv
  status:i = 0
  if (value.type == $MAL_ERROR_TYPE) ithen
    prints "Error: %s\n", value.string
    status = 1
  else
    prints "%s\n", pr_str(value)
  endif
  xout status
endop
</CsInstruments>
<CsScore>
f 0 z
</CsScore>
</CsoundSynthesizer>
