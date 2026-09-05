;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Deliberately curated. These concrete signatures follow Csound 7's
;; Engine/entry.c and Opcodes/{afilters,pan2}.c. No opcode-specific rendering.
opcode MalCsoundInstallOpcodes(env:MalEnv):MalEnv
  fn:MalValue init MalMkCsoundOpcode("cpsmidinn", "")
  fn init MalAppendValue(fn, MalCsoundSignature("i", "i", 1, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k", 1, "", 0))
  env init MalEnvSet(env, "csound/cpsmidinn", fn)

  fn init MalMkCsoundOpcode("poscil", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,i,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,a,i,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,a,i,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "k,k,i,i", 2, "", 0))
  env init MalEnvSet(env, "csound/poscil", fn)

  fn init MalMkCsoundOpcode("pluck", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "k,k,i,i,i,i,i", 5, "", 0))
  env init MalEnvSet(env, "csound/pluck", fn)

  fn init MalMkCsoundOpcode("linseg", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "i", 1, "i,i", 1))
  fn init MalAppendValue(fn, MalCsoundSignature("k", "i", 1, "i,i", 1))
  env init MalEnvSet(env, "csound/linseg", fn)

  fn init MalMkCsoundOpcode("tone", "a")
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,k,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a", "a,a,i", 2, "", 0))
  env init MalEnvSet(env, "csound/tone", fn)

  fn init MalMkCsoundOpcode("pan2", "a,a")
  fn init MalAppendValue(fn, MalCsoundSignature("a,a", "a,k,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a,a", "a,a,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a[]", "a,k,i", 2, "", 0))
  fn init MalAppendValue(fn, MalCsoundSignature("a[]", "a,a,i", 2, "", 0))
  env init MalEnvSet(env, "csound/pan2", fn)

  ;; Keep the existing stereo helper contract, though Csound outs is variadic.
  fn init MalMkCsoundOpcode("outs", "")
  fn init MalAppendValue(fn, MalCsoundSignature("", "a,a", 2, "", 0))
  env init MalEnvSet(env, "csound/outs", fn)
  xout env
endop
