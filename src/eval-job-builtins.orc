;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Each application below returns to the job dispatcher before running Lisp.
;; Frames 100-108 belong to these builtin continuations.
opcode MalEvalJobBuiltinContinue(slot:i, frame:MalEvalFrame):void
  malEvalJobs[slot].env = frame.env
  if (frame.index >= frame.limit) ithen
    if (frame.kind == 103) ithen
      name:S init frame.extra.string
      if (strcmp(name, "every?") == 0 || strcmp(name, "not-any?") == 0) ithen
        MalEvalJobReturn(slot, MalMkBool(1))
      elseif (strcmp(name, "not-every?") == 0) ithen
        MalEvalJobReturn(slot, MalMkBool(0))
      elseif (strcmp(name, "some") == 0) ithen
        MalEvalJobReturn(slot, MalMkValue($MAL_NIL_TYPE))
      else
        MalEvalJobReturn(slot, frame.data)
      endif
    else
      MalEvalJobReturn(slot, frame.data)
    endif
  else
    MalEvalJobPush(slot, frame)
    if (frame.kind == 100) ithen
      MalEvalJobSetApply(slot, frame.form, MalMkList1(MalAt(frame.aux, frame.index)))
    elseif (frame.kind == 101) ithen
      callArgs:MalValue init MalMkValue($MAL_LIST_TYPE)
      for column in [0 ... frame.aux.length - 1] do
        callArgs init MalAppendValue(callArgs, MalAt(MalAt(frame.aux, column), frame.index))
      od
      MalEvalJobSetApply(slot, frame.form, callArgs)
    elseif (frame.kind == 102) ithen
      MalEvalJobSetApply(slot, frame.form, MalMkList2(frame.data, MalAt(frame.aux, frame.index)))
    elseif (frame.kind == 103) ithen
      if (frame.flag == 1) ithen
        ;; drop-while stops calling its predicate after the first false result.
        MalEvalJobReturn(slot, MalMkBool(0))
      else
        MalEvalJobSetApply(slot, frame.form, MalMkList1(MalAt(frame.aux, frame.index)))
      endif
    else
      ;; take/drop copy one item per dispatcher step.
      MalEvalJobReturn(slot, MalAt(frame.aux, frame.index))
    endif
  endif
endop

opcode MalEvalJobBuiltinStart(slot:i, fn:MalValue, args:MalValue):i
  handled:i = 0
  if (fn.type == $MAL_BUILTIN_TYPE) ithen
    name:S init fn.string
    frame:MalEvalFrame init 0, 0, MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), MalMkValue($MAL_NIL_TYPE), 0, 0, 0
    frame.env = malEvalJobs[slot].env
    frame.index = 0
    frame.flag = 0

    if (strcmp(name, "apply") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length < 2) ithen
        MalEvalJobReturn(slot, MalMkError(sprintf("apply: expected at least 2 arguments, got %d", args.length)))
      elseif (MalIsSequential(MalAt(args, args.length - 1)) == 0) ithen
        MalEvalJobReturn(slot, MalMkError("apply: final argument must be list or vector"))
      else
        MalEvalJobSetApply(slot, MalAt(args, 0), MalFlattenApplyArgs(args))
      endif

    elseif (strcmp(name, "map") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length != 2) ithen
        MalEvalJobReturn(slot, MalArityError(name, 2, args.length))
      else
        sequence:MalValue init MalAt(args, 1)
        if (MalIsCsoundArray(sequence) == 1) ithen
          sequence init MalCsoundArraySeq(sequence)
        endif
        if (sequence.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, sequence)
        elseif (MalIsSequential(sequence) == 0) ithen
          MalEvalJobReturn(slot, MalMkError("map: second argument must be list or vector"))
        else
          frame.kind = 100
          frame.form init MalAt(args, 0)
          frame.aux init sequence
          frame.data init MalMkValue($MAL_LIST_TYPE)
          frame.limit = sequence.length
          MalEvalJobBuiltinContinue(slot, frame)
        endif
      endif

    elseif (strcmp(name, "mapv") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length < 2) ithen
        MalEvalJobReturn(slot, MalMkError("mapv: expected a function and at least one collection"))
      else
        collections:MalValue init MalMkValue($MAL_LIST_TYPE)
        size:i = -1
        failure:MalValue init MalMkValue($MAL_NIL_TYPE)
        for index in [1 ... args.length - 1] do
          sequence:MalValue init MalSeq(MalAt(args, index))
          if (sequence.type == $MAL_ERROR_TYPE) ithen
            failure init sequence
            break
          endif
          collections init MalAppendValue(collections, sequence)
          size = size < 0 ? sequence.length : min(size, sequence.length)
        od
        if (failure.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, failure)
        else
          frame.kind = 101
          frame.form init MalAt(args, 0)
          frame.aux init collections
          frame.data init MalMkValue($MAL_VECTOR_TYPE)
          frame.limit = size
          MalEvalJobBuiltinContinue(slot, frame)
        endif
      endif

    elseif (strcmp(name, "reduce") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length != 2 && args.length != 3) ithen
        MalEvalJobReturn(slot, MalMkError("reduce: expected 2 or 3 arguments"))
      else
        sequence:MalValue init MalSeq(MalAt(args, args.length - 1))
        if (sequence.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, sequence)
        elseif (args.length == 2 && sequence.length == 0) ithen
          ;; Empty reductions return the zero-argument call unchanged.
          MalEvalJobSetApply(slot, MalAt(args, 0), MalMkValue($MAL_LIST_TYPE))
        else
          frame.kind = 102
          frame.form init MalAt(args, 0)
          frame.aux init sequence
          frame.limit = sequence.length
          if (args.length == 3) ithen
            frame.data init MalAt(args, 1)
          else
            frame.data init MalAt(sequence, 0)
            frame.index = 1
          endif
          MalEvalJobBuiltinContinue(slot, frame)
        endif
      endif

    elseif ((strcmp(name, "filter") == 0 || strcmp(name, "filterv") == 0 || \
        strcmp(name, "remove") == 0 || strcmp(name, "keep") == 0 || \
        strcmp(name, "every?") == 0 || strcmp(name, "not-every?") == 0 || \
        strcmp(name, "some") == 0 || strcmp(name, "not-any?") == 0 || \
        strcmp(name, "take-while") == 0 || strcmp(name, "drop-while") == 0) && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length != 2) ithen
        MalEvalJobReturn(slot, MalArityError(name, 2, args.length))
      else
        sequence:MalValue init MalSeq(MalAt(args, 1))
        if (sequence.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, sequence)
        else
          frame.kind = 103
          frame.form init MalAt(args, 0)
          frame.aux init sequence
          frame.extra init MalMkString(name)
          frame.data init MalMkValue(strcmp(name, "filterv") == 0 ? $MAL_VECTOR_TYPE : $MAL_LIST_TYPE)
          frame.limit = sequence.length
          MalEvalJobBuiltinContinue(slot, frame)
        endif
      endif

    elseif (strcmp(name, "swap!") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length < 2) ithen
        MalEvalJobReturn(slot, MalMkError(sprintf("swap!: expected at least 2 arguments, got %d", args.length)))
      else
        atom:MalValue init MalAt(args, 0)
        if (atom.type != $MAL_ATOM_TYPE) ithen
          MalEvalJobReturn(slot, MalMkError("swap!: first argument must be an atom"))
        else
          frame.kind = 104
          frame.form init MalAt(args, 1)
          frame.data init atom
          frame.aux init MalCoreSlice(args, 2, args.length, 0)
          frame.index = malAtomVersions[atom.number]
          callArgs:MalValue init MalMkList1(MalAtomValue(atom))
          if (frame.aux.length > 0) ithen
            for index in [0 ... frame.aux.length - 1] do
              callArgs init MalAppendValue(callArgs, MalAt(frame.aux, index))
            od
          endif
          MalEvalJobPush(slot, frame)
          MalEvalJobSetApply(slot, frame.form, callArgs)
        endif
      endif

    elseif ((strcmp(name, "update") == 0 || strcmp(name, "update-in") == 0) && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length < 3) ithen
        MalEvalJobReturn(slot, MalMkError(sprintf("%s: invalid arguments", name)))
      else
        path:MalValue init MalMkList1(MalAt(args, 1))
        if (strcmp(name, "update-in") == 0) ithen
          path init MalSeq(MalAt(args, 1))
          if (path.length == 0 && path.type != $MAL_ERROR_TYPE) ithen
            path init MalMkList1(MalMkValue($MAL_NIL_TYPE))
          endif
        endif
        if (path.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, path)
        else
          old:MalValue init MalCoreGetIn(MalAt(args, 0), path, MalMkValue($MAL_NIL_TYPE))
          if (old.type == $MAL_ERROR_TYPE) ithen
            MalEvalJobReturn(slot, old)
          else
            frame.kind = 105
            frame.data init MalAt(args, 0)
            frame.aux init path
            callArgs:MalValue init MalMkList1(old)
            if (args.length > 3) ithen
              for index in [3 ... args.length - 1] do
                callArgs init MalAppendValue(callArgs, MalAt(args, index))
              od
            endif
            MalEvalJobPush(slot, frame)
            MalEvalJobSetApply(slot, MalAt(args, 2), callArgs)
          endif
        endif
      endif

    elseif ((strcmp(name, "take") == 0 || strcmp(name, "drop") == 0) && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length != 2) ithen
        MalEvalJobReturn(slot, MalArityError(name, 2, args.length))
      else
        amount:MalValue init MalAt(args, 0)
        sequence:MalValue init MalSeq(MalAt(args, 1))
        if (amount.type != $MAL_NUMBER_TYPE) ithen
          MalEvalJobReturn(slot, MalMkError(sprintf("%s: count must be a number", name)))
        elseif (sequence.type == $MAL_ERROR_TYPE) ithen
          MalEvalJobReturn(slot, sequence)
        else
          size:i = min(sequence.length, max(0, ceil(amount.number)))
          frame.kind = 106
          frame.data init MalMkValue($MAL_LIST_TYPE)
          frame.aux init sequence
          frame.index = strcmp(name, "take") == 0 ? 0 : size
          frame.limit = strcmp(name, "take") == 0 ? size : sequence.length
          MalEvalJobBuiltinContinue(slot, frame)
        endif
      endif

    elseif (strcmp(name, "eval") == 0 && lenarray(fn.env) == 0) ithen
      handled = 1
      if (args.length != 1) ithen
        MalEvalJobReturn(slot, MalArityError(name, 1, args.length))
      else
        root:MalEnv init MalEnvRoot(MalEnvHandle(frame.env))
        frame.kind = 108
        MalEvalJobPush(slot, frame)
        MalEvalJobSetEval(slot, MalAt(args, 0), root.id)
      endif

    elseif (strcmp(name, "load-file") == 0 && lenarray(fn.env) > 0) ithen
      handled = 1
      if (args.length != 1) ithen
        MalEvalJobReturn(slot, MalMkError("load-file: expected one argument"))
      else
        path:MalValue init MalAt(args, 0)
        if (path.type != $MAL_STRING_TYPE) ithen
          MalEvalJobReturn(slot, MalMkError("load-file: expected a filename string"))
        else
          MalEvalJobReturn(slot, MalMkError("load-file: load files before starting cooperative evaluation"))
        endif
      endif

    elseif (strcmp(name, "require") == 0 && lenarray(fn.env) > 0) ithen
      handled = 1
      root:MalEnv init MalEnvRoot(fn.env[0])
      result:MalValue init MalMkValue($MAL_NIL_TYPE)
      if (args.length > 0) ithen
        for index in [0 ... args.length - 1] do
          result init MalRequireSpecValid(MalAt(args, index))
          if (result.type == $MAL_ERROR_TYPE) ithen
            break
          endif
        od
        if (result.type != $MAL_ERROR_TYPE) ithen
          for index in [0 ... args.length - 1] do
            library:MalValue init MalAt(args, index)
            if (library.type == $MAL_VECTOR_TYPE) ithen
              library init MalAt(library, 0)
            endif
            nsIndex:i = MalNsFind(root.id, library.string)
            loaded:i = 0
            if (nsIndex >= 0) ithen
              loaded = malNamespaces[nsIndex].status == 1 ? 1 : 0
            endif
            if (loaded == 0) ithen
              result init MalMkError(sprintf("require: load namespace '%s' before starting cooperative evaluation", library.string))
              break
            endif
          od
        endif
      endif
      if (result.type != $MAL_ERROR_TYPE) ithen
        result init MalNsRequire(root, args)
      endif
      MalEvalJobReturn(slot, result)
    endif
  endif
  xout handled
endop

opcode MalEvalJobBuiltinResume(slot:i, frame:MalEvalFrame, value:MalValue):void
  malEvalJobs[slot].env = frame.env
  if (value.type == $MAL_ERROR_TYPE) ithen
    MalEvalJobReturn(slot, value)
  elseif (frame.kind == 100 || frame.kind == 101 || frame.kind == 106) ithen
    frame.data init MalAppendValue(frame.data, value)
    frame.index += 1
    MalEvalJobBuiltinContinue(slot, frame)
  elseif (frame.kind == 102) ithen
    if (value.type == $MAL_REDUCED_TYPE) ithen
      MalEvalJobReturn(slot, MalAt(value, 0))
    else
      frame.data init value
      frame.index += 1
      MalEvalJobBuiltinContinue(slot, frame)
    endif
  elseif (frame.kind == 103) ithen
    name:S init frame.extra.string
    truth:i = MalIsTruthy(value)
    done:i = 0
    if (strcmp(name, "some") == 0 || strcmp(name, "not-any?") == 0) ithen
      if (truth == 1) ithen
        done = 1
        if (strcmp(name, "some") == 0) ithen
          MalEvalJobReturn(slot, value)
        else
          MalEvalJobReturn(slot, MalMkBool(0))
        endif
      endif
    elseif (strcmp(name, "every?") == 0 || strcmp(name, "not-every?") == 0) ithen
      if (truth == 0) ithen
        done = 1
        MalEvalJobReturn(slot, MalMkBool(strcmp(name, "not-every?") == 0 ? 1 : 0))
      endif
    elseif (strcmp(name, "take-while") == 0 && truth == 0) ithen
      done = 1
      MalEvalJobReturn(slot, frame.data)
    else
      include:i = truth
      if (strcmp(name, "keep") == 0) ithen
        include = value.type != $MAL_NIL_TYPE ? 1 : 0
      elseif (strcmp(name, "remove") == 0) ithen
        include = 1 - truth
      elseif (strcmp(name, "drop-while") == 0) ithen
        if (truth == 0) ithen
          frame.flag = 1
        endif
        include = frame.flag
      endif
      if (include == 1) ithen
        if (strcmp(name, "keep") == 0) ithen
          frame.data init MalAppendValue(frame.data, value)
        else
          frame.data init MalAppendValue(frame.data, MalAt(frame.aux, frame.index))
        endif
      endif
    endif
    if (done == 0) ithen
      frame.index += 1
      MalEvalJobBuiltinContinue(slot, frame)
    endif
  elseif (frame.kind == 104) ithen
    atom:MalValue init frame.data
    if (frame.index != malAtomVersions[atom.number]) ithen
      ;; A callback changed the atom while this job yielded. Retry with its
      ;; latest value, including when another writer restored the old value.
      frame.index = malAtomVersions[atom.number]
      callArgs:MalValue init MalMkList1(MalAtomValue(atom))
      if (frame.aux.length > 0) ithen
        for index in [0 ... frame.aux.length - 1] do
          callArgs init MalAppendValue(callArgs, MalAt(frame.aux, index))
        od
      endif
      MalEvalJobPush(slot, frame)
      MalEvalJobSetApply(slot, frame.form, callArgs)
    else
      MalEvalJobReturn(slot, MalAtomSetValue(atom, value))
    endif
  elseif (frame.kind == 105) ithen
    MalEvalJobReturn(slot, MalCoreAssocIn(frame.data, frame.aux, 0, value))
  elseif (frame.kind == 108) ithen
    MalEvalJobReturn(slot, value)
  else
    MalEvalJobReturn(slot, MalMkError("unknown builtin continuation"))
  endif
endop
