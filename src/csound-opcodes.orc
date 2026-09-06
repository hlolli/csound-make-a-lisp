;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Each signature states outputs, fixed inputs, required input count, then
;; any repeated input group and its minimum count. Optional inputs stay absent
;; from the generated call so Csound supplies its defaults.
;;
;; Engine/entry.c defines the core signatures. Plugin signatures come from
;; Opcodes/{afilters,butter,dcblockr,oscbnk,pan2,reverbsc}.c.

opcode MalCsoundUnaryOpcode(name:S, rates:S):MalValue
  fn:MalValue init MalMkCsoundOpcode(name, "")
  types:S[] init MalCsoundTypeList(rates)
  for index in [0 ... lenarray(types) - 1] do
    fn init MalAppendValue(fn, MalCsoundSignature(types[index], types[index], 1, "", 0))
  od
  xout fn
endop

opcode MalCsoundInstallMathOpcodes(env:MalEnv):MalEnv
  names:S[] fillarray "abs", "sqrt", "sin", "cos", "tanh", "exp", "ampdb", "cpsoct", "int", "frac"
  for index in [0 ... lenarray(names) - 1] do
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), \
      MalCsoundUnaryOpcode(names[index], "i,k,a"))
  od
  env init MalEnvSet(env, "csound/dbamp", MalCsoundUnaryOpcode("dbamp", "i,k"))
  env init MalEnvSet(env, "csound/cpsmidinn", MalCsoundUnaryOpcode("cpsmidinn", "i,k"))
  env init MalEnvSet(env, "csound/cpspch", MalCsoundUnaryOpcode("cpspch", "i,k"))
  env init MalEnvSet(env, "csound/octpch", MalCsoundUnaryOpcode("octpch", "i,k"))
  xout env
endop

;; Table oscillators accept each combination of audio/control amplitude and
;; frequency at audio rate. Their control output takes control inputs only.
opcode MalCsoundTableOscillator(name:S):MalValue
  fn:MalValue init MalMkCsoundOpcode(name, "a")
  rates:S[] fillarray "k", "a"
  for amplitude in [0 ... 1] do
    for frequency in [0 ... 1] do
      inputs:S init sprintf("%s,%s,i,i", rates[amplitude], rates[frequency])
      fn init MalAppendValue(fn, MalCsoundSignature("a", inputs, 2, "", 0))
    od
  od
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k,k,i,i", 2, "", 0))
  xout fn
endop

opcode MalCsoundInstallOscillatorOpcodes(env:MalEnv):MalEnv
  env init MalEnvSet(env, "csound/oscil", MalCsoundTableOscillator("oscil"))
  env init MalEnvSet(env, "csound/poscil", MalCsoundTableOscillator("poscil"))
  env init MalEnvSet(env, "csound/oscili", MalCsoundTableOscillator("oscili"))

  fn:MalValue init MalMkCsoundOpcode("phasor", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,i", 1, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,i", 1, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k,i", 1, "", 0))
  env init MalEnvSet(env, "csound/phasor", fn)

  fn init MalMkCsoundOpcode("vco2", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,i,k,k,i", 2, "", 0))
  env init MalEnvSet(env, "csound/vco2", fn)

  fn init MalMkCsoundOpcode("pluck", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,i,i,i,i,i", 5, "", 0))
  env init MalEnvSet(env, "csound/pluck", fn)

  ;; Classic harmonic and FM voices use control-rate modulation inputs.
  fn init MalMkCsoundOpcode("buzz", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,k,i,i", 4, "", 0))
  env init MalEnvSet(env, "csound/buzz", fn)
  fn init MalMkCsoundOpcode("gbuzz", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,k,k,k,i,i", 6, "", 0))
  env init MalEnvSet(env, "csound/gbuzz", fn)
  fn init MalMkCsoundOpcode("foscil", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,k,k,k,i,i", 5, "", 0))
  env init MalEnvSet(env, "csound/foscil", fn)
  xout env
endop

opcode MalCsoundInstallEnvelopeOpcodes(env:MalEnv):MalEnv
  names:S[] fillarray "linseg", "expseg"
  for index in [0 ... lenarray(names) - 1] do
    fn:MalValue init MalMkCsoundOpcode(names[index], "a")
    fn init MalAppendValue(fn, MalCsoundSignature("a", "i", 1, "i,i", 1))
    fn init MalAppendValue(fn, MalCsoundSignature("k", "i", 1, "i,i", 1))
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), fn)
  od

  names init fillarray("line", "expon")
  for index in [0 ... lenarray(names) - 1] do
    fn init MalMkCsoundOpcode(names[index], "a")
    fn init MalAppendValue(fn, MalCsoundSignature("a", "i,i,i", 3, "", 0))
    fn init MalAppendValue(fn, MalCsoundSignature("k", "i,i,i", 3, "", 0))
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), fn)
  od

  fn init MalMkCsoundOpcode("adsr", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "i,i,i,i,i", 4, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "i,i,i,i,i", 4, "", 0))
  env init MalEnvSet(env, "csound/adsr", fn)

  fn init MalMkCsoundOpcode("linen", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,i,i,i", 4, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,i,i,i", 4, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k,i,i,i", 4, "", 0))
  env init MalEnvSet(env, "csound/linen", fn)
  xout env
endop

opcode MalCsoundInstallFilterOpcodes(env:MalEnv):MalEnv
  names:S[] fillarray "tone", "butterlp", "butterhp"
  for index in [0 ... lenarray(names) - 1] do
    fn:MalValue init MalMkCsoundOpcode(names[index], "a")
    fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i", 2, "", 0))
    fn init MalAppendValue(fn, MalCsoundSignature("a", "a,a,i", 2, "", 0))
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), fn)
  od

  fn init MalMkCsoundOpcode("reson", "a")
  rates:S[] fillarray "k", "a"
  for center in [0 ... 1] do
    for bandwidth in [0 ... 1] do
      inputs:S init sprintf("a,%s,%s,i,i", rates[center], rates[bandwidth])
      fn init MalAppendValue(fn, MalCsoundSignature("a", inputs, 3, "", 0))
    od
  od
  env init MalEnvSet(env, "csound/reson", fn)

  fn init MalMkCsoundOpcode("dcblock2", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,i,i", 1, "", 0))
  env init MalEnvSet(env, "csound/dcblock2", fn)

  fn init MalMkCsoundOpcode("portk", "k")
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k,k,i", 2, "", 0))
  env init MalEnvSet(env, "csound/portk", fn)
  xout env
endop

opcode MalCsoundInstallEffectOpcodes(env:MalEnv):MalEnv
  fn:MalValue init MalMkCsoundOpcode("delay", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,i,i", 2, "", 0))
  env init MalEnvSet(env, "csound/delay", fn)

  fn init MalMkCsoundOpcode("vdelay", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i,i", 3, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,a,i,i", 3, "", 0))
  env init MalEnvSet(env, "csound/vdelay", fn)

  fn init MalMkCsoundOpcode("reverbsc", "a,a")
  fn init MalAppendValue(fn, MalCsoundSignature("a,a", "a,a,k,k,i,i,i", 4, "", 0))
  env init MalEnvSet(env, "csound/reverbsc", fn)

  fn init MalMkCsoundOpcode("pan2", "a,a")
  fn init MalAppendValue(fn, MalCsoundSignature("a,a", "a,k,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a,a", "a,a,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a[]", "a,k,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a[]", "a,a,i", 2, "", 0))
  env init MalEnvSet(env, "csound/pan2", fn)

  ;; Keep the stereo helper contract, though Csound outs is variadic.
  fn init MalMkCsoundOpcode("outs", "")
  fn init MalAppendValue(fn, MalCsoundSignature("", "a,a", 2, "", 0))
  env init MalEnvSet(env, "csound/outs", fn)

  fn init MalMkCsoundOpcode("balance", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,a,i,i", 2, "", 0))
  env init MalEnvSet(env, "csound/balance", fn)
  fn init MalMkCsoundOpcode("reverb", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i", 2, "", 0))
  env init MalEnvSet(env, "csound/reverb", fn)

  names:S[] fillarray "comb", "alpass"
  for index in [0 ... lenarray(names) - 1] do
    fn init MalMkCsoundOpcode(names[index], "a")
    fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i,i,i", 3, "", 0))
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), fn)
  od
  xout env
endop

opcode MalCsoundInstallTableOpcodes(env:MalEnv):MalEnv
  names:S[] fillarray "table", "tablei"
  rates:S[] fillarray "i", "k", "a"
  for nameIndex in [0 ... lenarray(names) - 1] do
    fn:MalValue init MalMkCsoundOpcode(names[nameIndex], "")
    for index in [0 ... lenarray(rates) - 1] do
      inputs:S init sprintf("%s,i,i,i,i", rates[index])
      fn init MalAppendValue(fn, MalCsoundSignature(rates[index], inputs, 2, "", 0))
    od
    env init MalEnvSet(env, sprintf("csound/%s", names[nameIndex]), fn)
  od
  xout env
endop

opcode MalCsoundInstallArrayOpcodes(env:MalEnv):MalEnv
  fn:MalValue init MalMkCsoundOpcode("sumarray", "")
  rates:S[] fillarray "i", "k", "a"
  for index in [0 ... lenarray(rates) - 1] do
    inputs:S init sprintf("%s[]", rates[index])
    fn init MalAppendValue(fn, MalCsoundSignature(rates[index], inputs, 1, "", 0))
  od
  env init MalEnvSet(env, "csound/sumarray", fn)

  ;; The array's element type does not choose lenarray's output rate.
  ;; Default to init and let csound/at-rate select the control overload.
  fn init MalMkCsoundOpcode("lenarray", "i")
  outputs:S[] fillarray "i", "k"
  arrays:S[] fillarray "i[]", "k[]", "a[]", "S[]"
  for output in [0 ... lenarray(outputs) - 1] do
    for element in [0 ... lenarray(arrays) - 1] do
      inputs init sprintf("%s,i", arrays[element])
      fn init MalAppendValue(fn, MalCsoundSignature(outputs[output], inputs, 1, "", 0))
    od
  od
  env init MalEnvSet(env, "csound/lenarray", fn)
  xout env
endop

;; Noise accepts control frequency and control or audio amplitude.
opcode MalCsoundInstallNoiseOpcodes(env:MalEnv):MalEnv
  names:S[] fillarray "rand", "randh", "randi"
  for index in [0 ... lenarray(names) - 1] do
    fn:MalValue init MalMkCsoundOpcode(names[index], "a")
    tail:S init index == 0 ? ",i,i,i" : ",k,i,i,i"
    required:i = index == 0 ? 1 : 2
    fn init MalAppendValue(fn, MalCsoundSignature("a", strcat("k", tail), required, "", 0))
    fn init MalAppendValue(fn, MalCsoundSignature("a", strcat("a", tail), required, "", 0))
    fn init MalAppendValue(fn, MalCsoundSignature("k", strcat("k", tail), required, "", 0))
    env init MalEnvSet(env, sprintf("csound/%s", names[index]), fn)
  od

  xout env
endop

opcode MalCsoundInstallChannelOpcodes(env:MalEnv):MalEnv
  fn:MalValue init MalMkCsoundOpcode("chnget", "k")
  rates:S[] fillarray "i", "k", "a", "S"
  for index in [0 ... lenarray(rates) - 1] do
    fn init MalAppendValue(fn, MalCsoundSignature(rates[index], "S", 1, "", 0))
  od
  env init MalEnvSet(env, "csound/chnget", fn)
  fn init MalMkCsoundOpcode("chnmix", "")
  fn init MalAppendValue(fn, MalCsoundSignature("", "a,S", 2, "", 0))
  env init MalEnvSet(env, "csound/chnmix", fn)
  fn init MalMkCsoundOpcode("chnclear", "")
  fn init MalAppendValue(fn, MalCsoundSignature("", "", 0, "S", 1))
  env init MalEnvSet(env, "csound/chnclear", fn)
  xout env
endop

opcode MalCsoundInstallOpcodes(env:MalEnv):MalEnv
  env init MalCsoundInstallMathOpcodes(env)
  env init MalCsoundInstallOscillatorOpcodes(env)
  env init MalCsoundInstallEnvelopeOpcodes(env)
  env init MalCsoundInstallFilterOpcodes(env)
  env init MalCsoundInstallEffectOpcodes(env)
  env init MalCsoundInstallTableOpcodes(env)
  env init MalCsoundInstallArrayOpcodes(env)
  env init MalCsoundInstallNoiseOpcodes(env)
  env init MalCsoundInstallChannelOpcodes(env)
  xout env
endop
