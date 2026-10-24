;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; A job saves evaluator continuations between init passes. Each step runs at
;; most its budget of transitions; builtins run one native operation at a
;; time. Jobs share ordinary environments and atoms, so writes remain visible
;; between steps. Cancellation releases scopes; it does not undo writes.
;; Core frames: 1 collection/arguments, 2 if, 3 do, 4 let binding, 5 call
;; head, 6 definition, 7 try, 8 macro expansion, 9 scope cleanup. Builtin
;; continuations use kinds 100 and above.
struct MalEvalFrame kind:i, env:i, form:MalValue, data:MalValue, aux:MalValue, extra:MalValue, index:i, limit:i, flag:i
struct MalEvalJob id:i, status:i, env:i, mode:i, top:i, depth:i

malEvalJobs@global:MalEvalJob[] init 16
malEvalJobNextId@global:i init 1
;; Keep payloads in parallel arrays: Csound cannot assign a nested UDT member
;; of a struct-array element directly. Scalars in MalEvalJob need no copies.
malEvalJobAsts@global:MalValue[] init 16
malEvalJobValues@global:MalValue[] init 16
malEvalJobFunctions@global:MalValue[] init 16
malEvalJobArguments@global:MalValue[] init 16
malEvalJobFrames@global:MalEvalFrame[] init 256
malEvalJobFrameNext@global:i[] init 256
malEvalJobFrameCount@global:i init 0
malEvalJobFrameFree@global:i init -1

opcode MalEvalJobSlot(id:i):i
  result:i = -1
  if (id > 0) ithen
    for slot in [0 ... lenarray(malEvalJobs) - 1] do
      if (malEvalJobs[slot].id == id) ithen
        result = slot
        break
      endif
    od
  endif
  xout result
endop

opcode MalEvalJobPush(slot:i, frame:MalEvalFrame):void
  index:i = malEvalJobFrameFree
  if (index >= 0) ithen
    malEvalJobFrameFree = malEvalJobFrameNext[index]
  else
    index = malEvalJobFrameCount
    capacity:i = lenarray(malEvalJobFrames)
    if (index >= capacity) ithen
      saved:MalEvalFrame[] init capacity
      links:i[] init capacity
      for offset in [0 ... capacity - 1] do
        saved[offset] init malEvalJobFrames[offset]
        links[offset] = malEvalJobFrameNext[offset]
      od
      malEvalJobFrames init capacity * 2
      malEvalJobFrameNext init capacity * 2
      for offset in [0 ... capacity - 1] do
        malEvalJobFrames[offset] init saved[offset]
        malEvalJobFrameNext[offset] = links[offset]
      od
    endif
    malEvalJobFrameCount += 1
  endif
  malEvalJobFrames[index] init frame
  malEvalJobFrameNext[index] = malEvalJobs[slot].top
  malEvalJobs[slot].top = index
  malEvalJobs[slot].depth = malEvalJobs[slot].depth + 1
endop

opcode MalEvalJobPop(slot:i):MalEvalFrame
  zero:i = 0
  index:i = malEvalJobs[slot].top
  frame:MalEvalFrame init malEvalJobFrames[index]
  malEvalJobs[slot].top = malEvalJobFrameNext[index]
  malEvalJobs[slot].depth = malEvalJobs[slot].depth - 1
  malEvalJobFrameNext[index] = malEvalJobFrameFree
  malEvalJobFrameFree = index
  empty:MalEvalFrame init zero, zero, MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), zero, zero, zero
  malEvalJobFrames[index] init empty
  xout frame
endop

opcode MalEvalJobOwnEnv(slot:i, id:i):void
  kind:i = 9
  zero:i = 0
  frame:MalEvalFrame init kind, id, MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), zero, zero, zero
  MalEvalJobPush(slot, frame)
endop

opcode MalEvalJobSetEval(slot:i, ast:MalValue, env:i):void
  malEvalJobAsts[slot] init ast
  malEvalJobs[slot].env = env
  malEvalJobs[slot].mode = 0
endop

opcode MalEvalJobSetApply(slot:i, fn:MalValue, args:MalValue):void
  malEvalJobFunctions[slot] init fn
  malEvalJobArguments[slot] init args
  malEvalJobs[slot].mode = 2
endop

opcode MalEvalJobReturn(slot:i, value:MalValue):void
  malEvalJobValues[slot] init value
  malEvalJobs[slot].mode = 1
endop

opcode MalEvalJobFail(slot:i, message:S):void
  MalEvalJobReturn(slot, MalMkError(message))
endop

;; Loading an unseen module would enter the synchronous evaluator. Already
;; loaded libraries can safely install aliases and refers in a job.
opcode MalEvalJobRequireReady(env:MalEnv, specs:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  root:MalEnv init MalEnvRoot(env)
  if (specs.length > 0) ithen
    for index in [0 ... specs.length - 1] do
      result init MalRequireSpecValid(MalAt(specs, index))
      if (result.type == $MAL_ERROR_TYPE) ithen
        break
      endif
    od
    if (result.type != $MAL_ERROR_TYPE) ithen
      for index in [0 ... specs.length - 1] do
        library:MalValue init MalAt(specs, index)
        if (library.type == $MAL_VECTOR_TYPE) ithen
          library init MalAt(library, 0)
        endif
        nsIndex:i = MalNsFind(root.id, library.string)
        if (nsIndex < 0) ithen
          result init MalMkError(sprintf("require: load '%s' before starting an evaluation job", library.string))
        elseif (malNamespaces[nsIndex].status != 1) ithen
          result init MalMkError(sprintf("require: load '%s' before starting an evaluation job", library.string))
        endif
        if (result.type == $MAL_ERROR_TYPE) ithen
          break
        endif
      od
    endif
  endif
  xout result
endop

opcode MalEvalJobNamespace(ast:MalValue, env:MalEnv):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  specs:MalValue init MalMkValue($MAL_LIST_TYPE)
  valid:i = 0
  root:MalEnv init MalEnvRoot(env)
  if (ast.length >= 2 && strlen(root.namespace) > 0) ithen
    valid = MalNsNameValid(MalAt(ast, 1))
  endif
  ;; Syntax errors must win over a later module-load check, as in ns itself.
  if (valid == 1 && ast.length > 2) ithen
    for index in [2 ... ast.length - 1] do
      clause:MalValue init MalAt(ast, index)
      if (clause.type != $MAL_LIST_TYPE || clause.length == 0) ithen
        valid = 0
      else
        head:MalValue init MalAt(clause, 0)
        if (head.type != $MAL_KEYWORD_TYPE || strcmp(head.string, "require") != 0) ithen
          valid = 0
        elseif (clause.length > 1) ithen
          for item in [1 ... clause.length - 1] do
            spec:MalValue init MalAt(clause, item)
            check:MalValue init MalRequireSpecValid(spec)
            if (check.type == $MAL_ERROR_TYPE) ithen
              valid = 0
              break
            endif
            specs init MalAppendValue(specs, spec)
          od
        endif
      endif
      if (valid == 0) ithen
        break
      endif
    od
  endif
  if (valid == 1) ithen
    result init MalEvalJobRequireReady(root, specs)
  endif
  if (result.type != $MAL_ERROR_TYPE) ithen
    result init MalEvalNamespace(ast, env)
  endif
  xout result
endop

opcode MalEvalJobDefine(slot:i, ast:MalValue, asMacro:i, atRoot:i):void
  zero:i = 0
  head:MalValue init MalAt(ast, 0)
  if (ast.length != 3) ithen
    MalEvalJobReturn(slot, MalArityError(head.string, 2, ast.length - 1))
  else
    name:MalValue init MalAt(ast, 1)
    if (name.type != $MAL_SYMBOL_TYPE) ithen
      MalEvalJobFail(slot, sprintf("%s: first argument must be a symbol", head.string))
    else
      env:MalEnv init MalEnvResolve(MalEnvHandle(malEvalJobs[slot].env))
      definitionEnv:MalEnv init env
      key:MalValue init MalMkString(name.string)
      if (atRoot == 1 || lenarray(env.outer) == 0) ithen
        key init MalDefinitionKey(env, name.string)
        definitionEnv init MalEnvRoot(env)
      endif
      if (key.type == $MAL_ERROR_TYPE) ithen
        MalEvalJobReturn(slot, key)
      else
        frame:MalEvalFrame init zero, zero, MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), zero, zero, zero
        frame.kind = 6
        frame.env = env.id
        frame.form init MalAt(ast, 2)
        frame.data init key
        frame.aux init head
        frame.index = definitionEnv.id
        frame.flag = asMacro
        MalEvalJobPush(slot, frame)
        MalEvalJobSetEval(slot, frame.form, env.id)
      endif
    endif
  endif
endop

opcode MalEvalJobLetNext(slot:i, frame:MalEvalFrame):void
  if (frame.index >= frame.data.length) ithen
    MalEvalJobSetEval(slot, frame.form, frame.env)
  else
    name:MalValue init MalAt(frame.data, frame.index)
    if (name.type != $MAL_SYMBOL_TYPE) ithen
      MalEvalJobFail(slot, "let*: binding name must be a symbol")
    else
      MalEvalJobPush(slot, frame)
      MalEvalJobSetEval(slot, MalAt(frame.data, frame.index + 1), frame.env)
    endif
  endif
endop

#include "src/eval-job-builtins.orc"

opcode MalEvalJobEval(slot:i):void
  zero:i = 0
  ast:MalValue init malEvalJobAsts[slot]
  env:MalEnv init MalEnvHandle(malEvalJobs[slot].env)
  if (malDebugEvalBindingSeen == 1) ithen
    debug:MalValue init MalResolveSymbol(env, "DEBUG-EVAL")
    if (debug.type != $MAL_ERROR_TYPE && MalIsTruthy(debug) == 1) ithen
      prints "EVAL: %s\n", pr_str(ast)
    endif
  endif
  frame:MalEvalFrame init zero, env.id, ast, MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), zero, zero, zero
  if (ast.type == $MAL_SYMBOL_TYPE) ithen
    MalEvalJobReturn(slot, MalResolveSymbol(env, ast.string))
  elseif (ast.type == $MAL_VECTOR_TYPE || ast.type == $MAL_HASH_MAP_TYPE) ithen
    if (ast.length == 0) ithen
      MalEvalJobReturn(slot, MalMkValue(ast.type))
    else
      frame.kind = 1
      frame.data init MalMkValue(ast.type)
      frame.index = ast.type == $MAL_HASH_MAP_TYPE ? 1 : 0
      MalEvalJobPush(slot, frame)
      MalEvalJobSetEval(slot, MalAt(ast, frame.index), env.id)
    endif
  elseif (ast.type != $MAL_LIST_TYPE) ithen
    MalEvalJobReturn(slot, ast)
  elseif (ast.length == 0) ithen
    MalEvalJobReturn(slot, MalMkValue($MAL_LIST_TYPE))
  else
    head:MalValue init MalAt(ast, 0)
    if (MalIsSymbolNamed(head, "ns") == 1) ithen
      MalEvalJobReturn(slot, MalEvalJobNamespace(ast, env))
    elseif (MalIsSymbolNamed(head, "quote") == 1) ithen
      MalEvalJobReturn(slot, MalEvalQuote(ast))
    elseif (MalIsSymbolNamed(head, "quasiquote") == 1) ithen
      if (ast.length != 2) ithen
        MalEvalJobReturn(slot, MalArityError("quasiquote", 1, ast.length - 1))
      else
        quoted:MalValue init MalQuasiquote(MalAt(ast, 1))
        if (quoted.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, quoted)
        else
          MalEvalJobSetEval(slot, quoted, env.id)
        endif
      endif
    elseif (MalIsSymbolNamed(head, "def") == 1 || MalIsSymbolNamed(head, "def!") == 1 || MalIsSymbolNamed(head, "defmacro!") == 1) ithen
      MalEvalJobDefine(slot, ast, MalIsSymbolNamed(head, "defmacro!"), MalIsSymbolNamed(head, "def"))
    elseif (MalIsSymbolNamed(head, "defn") == 1 || MalIsSymbolNamed(head, "defmacro") == 1) ithen
      if (ast.length < 3) ithen
        MalEvalJobFail(slot, sprintf("%s: expected a name, parameter vector, and body", head.string))
      else
        name:MalValue init MalAt(ast, 1)
        if (name.type != $MAL_SYMBOL_TYPE) ithen
          MalEvalJobFail(slot, sprintf("%s: first argument must be a symbol", head.string))
        else
          expanded:MalValue init MalExpandFn(ast, 2, head.string)
          if (expanded.type == $MAL_ERROR_TYPE) ithen
            MalEvalJobReturn(slot, expanded)
          else
            MalEvalJobDefine(slot, MalMkList3(head, name, expanded), MalIsSymbolNamed(head, "defmacro"), 1)
          endif
        endif
      endif
    elseif (MalIsSymbolNamed(head, "fn") == 1) ithen
      expanded:MalValue init MalExpandFn(ast, 1, "fn")
      if (expanded.type == $MAL_ERROR_TYPE) ithen
        MalEvalJobReturn(slot, expanded)
      else
        MalEvalJobSetEval(slot, expanded, env.id)
      endif
    elseif (MalIsSymbolNamed(head, "fn*") == 1) ithen
      value:MalValue, unused:MalEnv = MalEvalFn(ast, env)
      MalEvalJobReturn(slot, value)
    elseif (MalIsSymbolNamed(head, "if") == 1) ithen
      if (ast.length < 3 || ast.length > 4) ithen
        MalEvalJobFail(slot, sprintf("if: expected 2 or 3 arguments, got %d", ast.length - 1))
      else
        frame.kind = 2
        MalEvalJobPush(slot, frame)
        MalEvalJobSetEval(slot, MalAt(ast, 1), env.id)
      endif
    elseif (MalIsSymbolNamed(head, "do") == 1) ithen
      if (ast.length == 1) ithen
        MalEvalJobReturn(slot, MalMkValue($MAL_NIL_TYPE))
      else
        if (ast.length > 2) ithen
          frame.kind = 3
          frame.index = 2
          MalEvalJobPush(slot, frame)
        endif
        MalEvalJobSetEval(slot, MalAt(ast, 1), env.id)
      endif
    elseif (MalIsSymbolNamed(head, "let*") == 1 || MalIsSymbolNamed(head, "let") == 1) ithen
      immutable:i = MalIsSymbolNamed(head, "let")
      body:MalValue init MalMkValue($MAL_NIL_TYPE)
      if (immutable == 1) ithen
        body init MalLetBody(ast)
      elseif (ast.length != 3) ithen
        body init MalArityError("let*", 2, ast.length - 1)
      else
        body init MalAt(ast, 2)
      endif
      if (body.type == $MAL_ERROR_TYPE) ithen
        MalEvalJobReturn(slot, body)
      else
        bindings:MalValue init MalAt(ast, 1)
        if (MalIsSequential(bindings) == 0) ithen
          MalEvalJobFail(slot, "let*: bindings must be list or vector")
        elseif (bindings.length % 2 != 0) ithen
          MalEvalJobFail(slot, "let*: bindings must contain even number of forms")
        else
          letEnv:MalEnv init MalMkEnvWithOuter(env)
          MalEvalJobOwnEnv(slot, letEnv.id)
          frame.kind = 4
          frame.env = letEnv.id
          frame.form init body
          frame.data init bindings
          frame.flag = immutable
          MalEvalJobLetNext(slot, frame)
        endif
      endif
    elseif (MalIsSymbolNamed(head, "try*") == 1) ithen
      if (ast.length < 2 || ast.length > 3) ithen
        MalEvalJobFail(slot, sprintf("try*: expected 1 or 2 arguments, got %d", ast.length - 1))
      elseif (ast.length == 2) ithen
        MalEvalJobSetEval(slot, MalAt(ast, 1), env.id)
      else
        catcher:MalValue init MalAt(ast, 2)
        if (MalIsForm(catcher, "catch*") == 0 || catcher.length != 3) ithen
          MalEvalJobFail(slot, "try*: second argument must be (catch* symbol handler)")
        else
          binding:MalValue init MalAt(catcher, 1)
          if (binding.type != $MAL_SYMBOL_TYPE) ithen
            MalEvalJobFail(slot, "catch*: binding must be a symbol")
          else
            frame.kind = 7
            frame.form init catcher
            MalEvalJobPush(slot, frame)
            MalEvalJobSetEval(slot, MalAt(ast, 1), env.id)
          endif
        endif
      endif
    else
      frame.kind = 5
      MalEvalJobPush(slot, frame)
      MalEvalJobSetEval(slot, head, env.id)
    endif
  endif
endop

opcode MalEvalJobResume(slot:i):void
  value:MalValue init malEvalJobValues[slot]
  depth:i = malEvalJobs[slot].depth
  if (depth == 0) ithen
    malEvalJobs[slot].status = 1
  else
    frame:MalEvalFrame init MalEvalJobPop(slot)
    malEvalJobs[slot].env = frame.env
    if (frame.kind == 9) ithen
      MalEnvRelease(MalEnvHandle(frame.env))
    elseif (value.type == $MAL_ERROR_TYPE) ithen
      if (frame.kind == 7) ithen
        catchEnv:MalEnv init MalMkEnvWithOuter(MalEnvHandle(frame.env))
        MalEvalJobOwnEnv(slot, catchEnv.id)
        binding:MalValue init MalAt(frame.form, 1)
        catchEnv init MalEnvSet(catchEnv, binding.string, MalErrorPayload(value))
        MalEvalJobSetEval(slot, MalAt(frame.form, 2), catchEnv.id)
      endif
    elseif (frame.kind >= 100) ithen
      MalEvalJobBuiltinResume(slot, frame, value)
    elseif (frame.kind == 1) ithen
      ;; Vectors, map values, and call arguments retain left-to-right order.
      if (frame.data.type == $MAL_HASH_MAP_TYPE) ithen
        frame.data init MalMapAssoc(frame.data, MalAt(frame.form, frame.index - 1), value)
        frame.index += 2
      else
        frame.data init MalAppendValue(frame.data, value)
        frame.index += 1
      endif
      if (frame.index < frame.form.length) ithen
        MalEvalJobPush(slot, frame)
        MalEvalJobSetEval(slot, MalAt(frame.form, frame.index), frame.env)
      elseif (frame.flag == 1) ithen
        MalEvalJobSetApply(slot, frame.aux, frame.data)
      else
        MalEvalJobReturn(slot, frame.data)
      endif
    elseif (frame.kind == 2) ithen
      if (MalIsTruthy(value) == 1) ithen
        MalEvalJobSetEval(slot, MalAt(frame.form, 2), frame.env)
      elseif (frame.form.length == 4) ithen
        MalEvalJobSetEval(slot, MalAt(frame.form, 3), frame.env)
      else
        MalEvalJobReturn(slot, MalMkValue($MAL_NIL_TYPE))
      endif
    elseif (frame.kind == 3) ithen
      next:MalValue init MalAt(frame.form, frame.index)
      frame.index += 1
      if (frame.index < frame.form.length) ithen
        MalEvalJobPush(slot, frame)
      endif
      MalEvalJobSetEval(slot, next, frame.env)
    elseif (frame.kind == 4) ithen
      letEnv:MalEnv init MalEnvHandle(frame.env)
      if (frame.flag == 1) ithen
        letEnv init MalMkEnvWithOuter(letEnv)
        MalEvalJobOwnEnv(slot, letEnv.id)
      endif
      name:MalValue init MalAt(frame.data, frame.index)
      letEnv init MalEnvSet(letEnv, name.string, value)
      frame.env = letEnv.id
      frame.index += 2
      MalEvalJobLetNext(slot, frame)
    elseif (frame.kind == 5) ithen
      if (MalIsMacro(value) == 1) ithen
        frame.kind = 8
        MalEvalJobPush(slot, frame)
        MalEvalJobSetApply(slot, value, MalUnevaluatedArgs(frame.form))
      elseif (frame.form.length == 1) ithen
        MalEvalJobSetApply(slot, value, MalMkValue($MAL_LIST_TYPE))
      else
        frame.kind = 1
        frame.aux init value
        frame.data init MalMkValue($MAL_LIST_TYPE)
        frame.index = 1
        frame.flag = 1
        MalEvalJobPush(slot, frame)
        MalEvalJobSetEval(slot, MalAt(frame.form, 1), frame.env)
      endif
    elseif (frame.kind == 6) ithen
      if (frame.flag == 1 && value.type != $MAL_FUNCTION_TYPE) ithen
        MalEvalJobFail(slot, sprintf("%s: value must be a function", frame.aux.string))
      else
        if (frame.flag == 1) ithen
          value init MalFunctionAsMacro(value)
        endif
        target:MalEnv init MalEnvSet(MalEnvHandle(frame.index), frame.data.string, value)
        if (MalIsFnForm(frame.form) == 1) ithen
          value init MalFunctionCaptureEnv(value, MalEnvHandle(frame.env))
          target init MalEnvSet(target, frame.data.string, value)
        endif
        MalEvalJobReturn(slot, value)
      endif
    elseif (frame.kind == 8) ithen
      MalEvalJobSetEval(slot, value, frame.env)
    endif
  endif
endop

opcode MalEvalJobApply(slot:i):void
  fn:MalValue init malEvalJobFunctions[slot]
  args:MalValue init malEvalJobArguments[slot]
  if (fn.type == $MAL_FUNCTION_TYPE) ithen
    result:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)
    if (result.type == $MAL_ERROR_TYPE) ithen
      MalEvalJobReturn(slot, result)
    else
      ;; Bind first: a returned closure may retain the preceding scope. Then
      ;; discard only tail-position cleanup frames before entering the body.
      MalEvalJobSetEval(slot, MalFunctionBody(fn), callEnv.id)
      malEvalJobs[slot].mode = 4
    endif
  elseif (MalEvalJobBuiltinStart(slot, fn, args) == 0) ithen
    MalEvalJobReturn(slot, MalApply(fn, args))
  endif
endop

;; Start returns a positive, never-reused token, or -1 when all slots are held.
;; Completed jobs keep their result until Cancel releases the token.
opcode MalEvalJobStart(ast:MalValue, env:MalEnv):i
  slot:i = -1
  for index in [0 ... lenarray(malEvalJobs) - 1] do
    if (malEvalJobs[index].id == 0) ithen
      slot = index
      break
    endif
  od
  id:i = -1
  if (slot >= 0) ithen
    id = malEvalJobNextId
    malEvalJobNextId += 1
    malEvalJobs[slot].id = id
    malEvalJobs[slot].status = 0
    malEvalJobs[slot].depth = 0
    malEvalJobs[slot].top = -1
    malEvalJobValues[slot] init MalMkValue($MAL_NIL_TYPE)
    MalEvalJobSetEval(slot, ast, env.id)
  endif
  xout id
endop

;; 0 means pending, 1 means complete (including a Lisp error), -1 means an
;; unknown token. A nonpositive budget observes status without running work.
opcode MalEvalJobStep(id:i, budget:i):i
  slot:i = MalEvalJobSlot(id)
  status:i = -1
  if (slot >= 0) ithen
    remaining:i = max(0, int(budget))
    while (remaining > 0 && malEvalJobs[slot].status == 0) do
      mode:i = malEvalJobs[slot].mode
      if (mode == 0) ithen
        MalEvalJobEval(slot)
      elseif (mode == 1) ithen
        MalEvalJobResume(slot)
      elseif (mode == 2) ithen
        MalEvalJobApply(slot)
      elseif (mode == 4) ithen
        tailScope:i = 0
        if (malEvalJobs[slot].depth > 0) ithen
          top:i = malEvalJobs[slot].top
          tailScope = malEvalJobFrames[top].kind == 9
        endif
        if (tailScope == 1) ithen
          frame:MalEvalFrame init MalEvalJobPop(slot)
          MalEnvRelease(MalEnvHandle(frame.env))
        else
          MalEvalJobOwnEnv(slot, malEvalJobs[slot].env)
          malEvalJobs[slot].mode = 0
        endif
      endif
      remaining -= 1
    od
    status = malEvalJobs[slot].status
  endif
  xout status
endop

opcode MalEvalJobResult(id:i):MalValue
  slot:i = MalEvalJobSlot(id)
  result:MalValue init MalMkError("evaluation job: unknown token")
  if (slot >= 0) ithen
    if (malEvalJobs[slot].status == 1) ithen
      result init malEvalJobValues[slot]
    else
      result init MalMkError("evaluation job: still pending")
    endif
  endif
  xout result
endop

opcode MalEvalJobCancel(id:i):void
  slot:i = MalEvalJobSlot(id)
  if (slot >= 0) ithen
    ;; A newly bound tail call has not yet installed its cleanup frame.
    if (malEvalJobs[slot].mode == 4) ithen
      MalEnvRelease(MalEnvHandle(malEvalJobs[slot].env))
    endif
    while (malEvalJobs[slot].depth > 0) do
      frame:MalEvalFrame init MalEvalJobPop(slot)
      if (frame.kind == 9) ithen
        MalEnvRelease(MalEnvHandle(frame.env))
      endif
    od
    malEvalJobs[slot].id = 0
    malEvalJobs[slot].status = -1
    malEvalJobs[slot].top = -1
    malEvalJobAsts[slot] init MalMkValue($MAL_NIL_TYPE)
    malEvalJobValues[slot] init MalMkValue($MAL_NIL_TYPE)
    malEvalJobFunctions[slot] init MalMkValue($MAL_NIL_TYPE)
    malEvalJobArguments[slot] init MalMkValue($MAL_NIL_TYPE)
  endif
endop
