;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Host UDOs take a frame number and return MalNativeReturn(frame, value).
;; The frame holds the argument list. Opcode objects in Csound 7 cannot pass
;; custom structs directly. Keep their instances outside evalstr: Csound
;; retains instrument 0 state after each compilation, including UDO arrays.
#define MAL_NATIVE_BINDING_LIMIT #64#
#define MAL_NATIVE_DEPTH_LIMIT #64#

malNativeInstances@global:Opcode[] init $MAL_NATIVE_BINDING_LIMIT * $MAL_NATIVE_DEPTH_LIMIT
malNativeDepths@global:i[] init $MAL_NATIVE_BINDING_LIMIT
malNativeCount@global:i init 0
malNativeArguments@global:MalValue[] init $MAL_NATIVE_DEPTH_LIMIT
malNativeResults@global:MalValue[] init $MAL_NATIVE_DEPTH_LIMIT
malNativeStackDepth@global:i init 0
malNativeRunners@global:Instr[] init $MAL_NATIVE_DEPTH_LIMIT
malNativeRunnerCount@global:i init 0
malNativeTarget@global:S init ""

opcode MalNativeArgs(frame:i):MalValue
  xout malNativeArguments[frame]
endop

opcode MalNativeReturn(frame:i, value:MalValue):i
  malNativeResults[frame] init value
  xout 0
endop

instr MalNativeRun
  ignored:i init malNativeInstances[p4], p5
endin

;; These instruments use the engine's sample rate and ksmps even when a host
;; registers or calls a binding from an instrument with a smaller local block.
instr MalNativeRegister
  definition:OpcodeDef opcoderef malNativeTarget
  ;; Keep instance creation out of the evaluator's static call graph.
  ;; Otherwise evalCode retains its state even for non-native expressions.
  while (malNativeRunnerCount < $MAL_NATIVE_DEPTH_LIMIT) do
    runner:Instr = create(MalNativeRun)
    malNativeRunners[malNativeRunnerCount] = runner
    malNativeRunnerCount += 1
  od
  ;; Array create gives each depth its own object. Repeating scalar create
  ;; at one call site can copy the same object into every slot.
  instances:Opcode[] init 0
  instances create definition, $MAL_NATIVE_DEPTH_LIMIT
  for depth in [0 ... $MAL_NATIVE_DEPTH_LIMIT - 1] do
    malNativeInstances[p4 * $MAL_NATIVE_DEPTH_LIMIT + depth] = instances[depth]
  od
endin

malNativeRegister@global:Instr = create(MalNativeRegister)
delete(malNativeRegister)

opcode MalMkNative(target:S):MalValue
  if (malNativeCount >= $MAL_NATIVE_BINDING_LIMIT) ithen
    result:MalValue init MalMkError(sprintf("native: at most %d host bindings per engine", $MAL_NATIVE_BINDING_LIMIT))
  else
    id:i = malNativeCount
    malNativeTarget strcpy target
    status:i = init(malNativeRegister, id)
    if (status != 0) ithen
      result:MalValue init MalMkError(sprintf("native: could not register %s", target))
    else
      malNativeCount += 1
      result:MalValue init MalMkBuiltin("__mal-native")
      result.number = id
    endif
  endif
  xout result
endop

opcode MalApplyNative(fn:MalValue, args:MalValue):MalValue
  id:i = fn.number
  frame:i = malNativeStackDepth
  if (id < 0 || id >= malNativeCount || id != int(id)) ithen
    result:MalValue init MalMkError("native: invalid host function")
  elseif (frame >= $MAL_NATIVE_DEPTH_LIMIT) ithen
    result:MalValue init MalMkError(sprintf("native: host call nesting exceeds %d", $MAL_NATIVE_DEPTH_LIMIT))
  else
    depth:i = malNativeDepths[id]
    malNativeArguments[frame] init args
    malNativeResults[frame] init MalMkError("native: host did not return a value")
    malNativeDepths[id] = depth + 1
    malNativeStackDepth = frame + 1
    ;; Instr init returns the error from its own pass so this pass can unwind
    ;; the MAL frame even when Csound aborts the host UDO.
    status:i = init(malNativeRunners[frame], id * $MAL_NATIVE_DEPTH_LIMIT + depth, frame)
    malNativeStackDepth = frame
    malNativeDepths[id] = depth
    if (status != 0) ithen
      result:MalValue init MalMkError("native: host initialization failed")
    else
      result:MalValue init malNativeResults[frame]
    endif
    malNativeArguments[frame] init MalMkValue($MAL_NIL_TYPE)
    malNativeResults[frame] init MalMkValue($MAL_NIL_TYPE)
  endif
  xout result
endop
