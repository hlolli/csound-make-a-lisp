;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalCoreSlice(sequence:MalValue, start:i, end:i, backwards:i):MalValue
  size:i = max(0, end - start)
  values:MalValue[] init size
  if (size > 0) ithen
    for index in [0 ... size - 1] do
      sourceIndex:i = backwards == 1 ? end - index - 1 : start + index
      values[index] init MalAt(sequence, sourceIndex)
    od
  endif
  result:MalValue init MalMkValue($MAL_LIST_TYPE)
  result.list init values
  result.length = size
  xout result
endop

opcode MalCoreLookup(collection:MalValue, key:MalValue):(MalValue, i)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  found:i = 0
  if (MalIsCsoundArray(collection) == 1) ithen
    result init MalCsoundArrayRead(collection, key, "get-in")
    found = 1
  elseif (collection.type == $MAL_HASH_MAP_TYPE) ithen
    index:i = MalMapFindKey(collection, key)
    if (index >= 0) ithen
      result init MalAt(collection, index + 1)
      found = 1
    endif
  elseif (collection.type == $MAL_VECTOR_TYPE || collection.type == $MAL_STRING_TYPE) ithen
    if (key.type == $MAL_NUMBER_TYPE && key.number == int(key.number)) ithen
      if (collection.type == $MAL_STRING_TYPE) ithen
        result init MalStringCharacter(collection.string, key.number)
        found = result.type != $MAL_NIL_TYPE
      elseif (key.number >= 0 && key.number < collection.length) ithen
        result init MalAt(collection, key.number)
        found = 1
      endif
    endif
  endif
  xout result, found
endop

opcode MalCoreNth(sequence:MalValue, index:MalValue, fallback:MalValue, hasFallback:i, extended:i):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  indexedString:i = extended == 1 && sequence.type == $MAL_STRING_TYPE
  indexedNil:i = extended == 1 && sequence.type == $MAL_NIL_TYPE
  if (MalIsCsoundArray(sequence) == 1) ithen
    result init MalCsoundArrayRead(sequence, index, "nth")
  elseif (MalIsSequential(sequence) == 0 && indexedString == 0 && indexedNil == 0) ithen
    message:S init extended == 1 ? "nth: expected a list, vector, string, Csound array, or nil" : "nth: first argument must be list or vector"
    result init MalMkError(message)
  elseif (index.type != $MAL_NUMBER_TYPE) ithen
    result init MalMkError("nth: index must be a number")
  elseif (index.number != int(index.number)) ithen
    result init MalMkError("nth: index must be an integer")
  elseif (indexedNil == 1) ithen
    result init fallback
  else
    missing:i = 0
    if (indexedString == 1) ithen
      result init MalStringCharacter(sequence.string, index.number)
      missing = result.type == $MAL_NIL_TYPE
    elseif (index.number < 0 || index.number >= sequence.length) ithen
      missing = 1
    else
      result init MalAt(sequence, index.number)
    endif
    if (missing == 1) ithen
      if (hasFallback == 1) ithen
        result init fallback
      else
        result init MalMkError("nth: index out of range")
      endif
    endif
  endif
  xout result
endop

opcode MalCoreApplyLookup(fn:MalValue, args:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (fn.type == $MAL_VECTOR_TYPE) ithen
    if (args.length != 1) ithen
      result init MalArityError("vector call", 1, args.length)
    else
      result init MalCoreNth(fn, MalAt(args, 0), result, 0, 0)
    endif
  elseif (args.length != 1 && args.length != 2) ithen
    name:S init fn.type == $MAL_KEYWORD_TYPE ? "keyword" : "map"
    result init MalMkError(sprintf("%s call: expected 1 or 2 arguments", name))
  else
    collection:MalValue init fn
    key:MalValue init MalAt(args, 0)
    if (fn.type == $MAL_KEYWORD_TYPE) ithen
      collection init key
      key init fn
    endif
    if (args.length == 2) ithen
      result init MalAt(args, 1)
    endif
    if (collection.type == $MAL_HASH_MAP_TYPE) ithen
      value:MalValue, found:i = MalCoreLookup(collection, key)
      if (found == 1) ithen
        result init value
      endif
    endif
  endif
  xout result
endop

opcode MalCoreAssoc(collection:MalValue, key:MalValue, value:MalValue):MalValue
  result:MalValue init MalMkError("expected a map, vector, or nil")
  if (MalIsCsoundArray(collection) == 1) ithen
    result init MalCsoundArrayWrite(collection, key, value)
  elseif (collection.type == $MAL_NIL_TYPE || collection.type == $MAL_HASH_MAP_TYPE) ithen
    result init MalMapAssoc(collection, key, value)
    result.metadata init collection.metadata
  elseif (collection.type == $MAL_VECTOR_TYPE) ithen
    if (key.type != $MAL_NUMBER_TYPE || key.number != int(key.number)) ithen
      result init MalMkError("vector key must be an integer")
    elseif (key.number < 0 || key.number > collection.length) ithen
      result init MalMkError("vector index out of bounds")
    else
      size:i = max(collection.length, key.number + 1)
      values:MalValue[] init size
      if (collection.length > 0) ithen
        for index in [0 ... collection.length - 1] do
          values[index] init MalAt(collection, index)
        od
      endif
      values[key.number] init value
      result init collection
      result.list init values
      result.length = size
      ;; Read the replacement array even if the input refers to a quoted AST.
      result.astRef = 0
    endif
  endif
  xout result
endop

opcode MalCoreAssocIn(collection:MalValue, path:MalValue, offset:i, value:MalValue):MalValue
  key:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (offset < path.length) ithen
    key init MalAt(path, offset)
  endif
  replacement:MalValue init value
  if (offset + 1 < path.length) ithen
    child:MalValue, found:i = MalCoreLookup(collection, key)
    if (child.type == $MAL_ERROR_TYPE) ithen
      replacement init child
    else
      replacement init MalCoreAssocIn(child, path, offset + 1, value)
    endif
  endif
  if (replacement.type == $MAL_ERROR_TYPE) ithen
    result:MalValue init replacement
  else
    result:MalValue init MalCoreAssoc(collection, key, replacement)
  endif
  xout result
endop

opcode MalCoreGetIn(collection:MalValue, path:MalValue, fallback:MalValue):MalValue
  result:MalValue init collection
  if (path.length > 0) ithen
    for index in [0 ... path.length - 1] do
      current:MalValue init result
      result, found:i = MalCoreLookup(current, MalAt(path, index))
      if (result.type == $MAL_ERROR_TYPE) ithen
        break
      elseif (found == 0) ithen
        result init fallback
        break
      endif
    od
  endif
  xout result
endop

opcode MalCoreReduce(args:MalValue):MalValue
  result:MalValue init MalMkError("reduce: expected 2 or 3 arguments")
  if (args.length == 2 || args.length == 3) ithen
    fn:MalValue init MalAt(args, 0)
    sequence:MalValue init MalSeq(MalAt(args, args.length - 1))
    if (sequence.type == $MAL_ERROR_TYPE) ithen
      result init sequence
    else
      start:i = 0
      if (args.length == 3) ithen
        result init MalAt(args, 1)
      elseif (sequence.length == 0) ithen
        result init MalApply(fn, MalMkValue($MAL_LIST_TYPE))
      else
        result init MalAt(sequence, 0)
        start = 1
      endif
      if (start < sequence.length) ithen
        for index in [start ... sequence.length - 1] do
          previous:MalValue init result
          result init MalApply(fn, MalMkList2(previous, MalAt(sequence, index)))
          if (result.type == $MAL_ERROR_TYPE) ithen
            break
          elseif (result.type == $MAL_REDUCED_TYPE) ithen
            result init MalAt(result, 0)
            break
          endif
        od
      endif
    endif
  endif
  xout result
endop

opcode MalCoreSelect(name:S, args:MalValue):MalValue
  result:MalValue init MalArityError(name, 2, args.length)
  if (args.length == 2) ithen
    fn:MalValue init MalAt(args, 0)
    sequence:MalValue init MalSeq(MalAt(args, 1))
    if (sequence.type == $MAL_ERROR_TYPE) ithen
      result init sequence
    else
      values:MalValue[] init sequence.length
      count:i = 0
      seek:i = strcmp(name, "some") == 0 || strcmp(name, "not-any?") == 0
      every:i = strcmp(name, "every?") == 0 || strcmp(name, "not-every?") == 0
      dropWhile:i = strcmp(name, "drop-while") == 0
      takeWhile:i = strcmp(name, "take-while") == 0
      negate:i = strcmp(name, "not-any?") == 0 || strcmp(name, "not-every?") == 0
      keeping:i = strcmp(name, "keep") == 0
      removing:i = strcmp(name, "remove") == 0
      dropping:i = dropWhile
      result init MalMkValue($MAL_NIL_TYPE)
      if (every == 1) ithen
        result init MalMkBool(1)
      endif
      if (sequence.length > 0) ithen
        for index in [0 ... sequence.length - 1] do
          value:MalValue init MalAt(sequence, index)
          matched:MalValue init MalMkBool(0)
          if (dropWhile == 0 || dropping == 1) ithen
            matched init MalApply(fn, MalMkList1(value))
          endif
          if (matched.type == $MAL_ERROR_TYPE) ithen
            result init matched
            break
          endif
          truth:i = MalIsTruthy(matched)
          if (seek == 1) ithen
            if (truth == 1) ithen
              result init matched
              break
            endif
          elseif (every == 1) ithen
            if (truth == 0) ithen
              result init MalMkBool(0)
              break
            endif
          elseif (takeWhile == 1 && truth == 0) ithen
            break
          else
            include:i = keeping == 1 ? matched.type != $MAL_NIL_TYPE : truth
            if (removing == 1) ithen
              include = 1 - truth
            elseif (dropWhile == 1) ithen
              if (truth == 0) ithen
                dropping = 0
              endif
              include = 1 - dropping
            endif
            if (include == 1) ithen
              if (keeping == 1) ithen
                values[count] init matched
              else
                values[count] init value
              endif
              count += 1
            endif
          endif
        od
      endif
      if (result.type != $MAL_ERROR_TYPE) ithen
        if (negate == 1) ithen
          result init MalMkBool(MalIsTruthy(result) == 0 ? 1 : 0)
        elseif (seek == 0 && every == 0) ithen
          result init MalMkValue(strcmp(name, "filterv") == 0 ? $MAL_VECTOR_TYPE : $MAL_LIST_TYPE)
          result.list init values
          result.length = count
        endif
      endif
    endif
  endif
  xout result
endop

opcode MalCoreMapInput(collection:MalValue):MalValue
  result:MalValue init collection
  if (MalIsSequential(collection) == 0) ithen
    result init MalSeq(collection)
  endif
  xout result
endop

opcode MalCoreMap(name:S, args:MalValue, resultType:i):MalValue
  result:MalValue init MalMkError(sprintf("%s: expected a function and at least one collection", name))
  if (args.length >= 2) ithen
    fn:MalValue init MalAt(args, 0)
    collectionCount:i = args.length - 1
    collections:MalValue[] init collectionCount
    size:i = -1
    failed:i = 0
    for index in [0 ... collectionCount - 1] do
      collection:MalValue init MalCoreMapInput(MalAt(args, index + 1))
      if (collection.type == $MAL_ERROR_TYPE) ithen
        result init collection
        failed = 1
        break
      endif
      collections[index] init collection
      size = size < 0 ? collection.length : min(size, collection.length)
    od
    if (failed == 0) ithen
      values:MalValue[] init size
      if (size > 0) ithen
        callValues:MalValue[] init collectionCount
        for index in [0 ... size - 1] do
          callArgs:MalValue init MalMkValue($MAL_LIST_TYPE)
          for column in [0 ... collectionCount - 1] do
            callValues[column] init MalAt(collections[column], index)
          od
          callArgs.list init callValues
          callArgs.length = collectionCount
          value:MalValue init MalApply(fn, callArgs)
          if (value.type == $MAL_ERROR_TYPE) ithen
            result init value
            failed = 1
            break
          endif
          values[index] init value
        od
      endif
      if (failed == 0) ithen
        result init MalMkValue(resultType)
        result.list init values
        result.length = size
      endif
    endif
  endif
  xout result
endop

opcode MalCoreRange(args:MalValue):MalValue
  result:MalValue init MalMkError("range: expected 1 to 3 arguments")
  if (args.length >= 1 && args.length <= 3) ithen
    start:MalValue init MalMkNumber(0)
    finish:MalValue init MalAt(args, 0)
    step:MalValue init MalMkNumber(1)
    if (args.length >= 2) ithen
      start init finish
      finish init MalAt(args, 1)
    endif
    if (args.length == 3) ithen
      step init MalAt(args, 2)
    endif
    if (start.type != $MAL_NUMBER_TYPE || finish.type != $MAL_NUMBER_TYPE || step.type != $MAL_NUMBER_TYPE) ithen
      result init MalMkError("range: expected numeric arguments")
    elseif (step.number == 0) ithen
      result init MalMkError("range: step must be nonzero")
    elseif (start.number - start.number != 0 || finish.number - finish.number != 0 || \
            step.number - step.number != 0) ithen
      result init MalMkError("range: arguments must be finite")
    else
      size:i = 0
      if ((step.number > 0 && start.number < finish.number) || \
          (step.number < 0 && start.number > finish.number)) ithen
        span:i = finish.number - start.number
        count:i = span / step.number
        if (span - span != 0) ithen
          ;; Opposite finite endpoints can have a span that overflows.
          count = finish.number / step.number - start.number / step.number
        endif
        ;; Test an extra candidate when a rounded ratio is an integer.
        size = max(1, floor(count) + 1)
      endif
      if (size >= 2147483648) ithen
        result init MalMkError("range: result exceeds the Csound array size limit")
      else
        values:MalValue[] init size
        count = 0
        if (size > 0) ithen
          lastOffset:i = (size - 1) * step.number
          scale:i = lastOffset - lastOffset == 0 ? 1 : 0.5
          scaledStart:i = start.number * scale
          scaledStep:i = step.number * scale
          for index in [0 ... size - 1] do
            value:i = (scaledStart + index * scaledStep) / scale
            if ((step.number > 0 && value >= finish.number) || \
                (step.number < 0 && value <= finish.number)) ithen
              break
            endif
            values[index] init MalMkNumber(value)
            count += 1
          od
        endif
        result init MalMkValue($MAL_LIST_TYPE)
        result.list init values
        result.length = count
      endif
    endif
  endif
  xout result
endop

opcode MalCoreExtremum(name:S, args:MalValue):MalValue
  result:MalValue init MalMkError(sprintf("%s: expected at least one argument", name))
  if (args.length > 0) ithen
    result init MalAt(args, 0)
    smallest:i = strcmp(name, "min") == 0
    for index in [0 ... args.length - 1] do
      value:MalValue init MalAt(args, index)
      if (value.type != $MAL_NUMBER_TYPE) ithen
        result init MalMkError(sprintf("%s: expected numeric arguments", name))
        break
      elseif (value.number != value.number || (smallest == 1 && value.number < result.number) || \
              (smallest == 0 && value.number > result.number)) ithen
        result init value
      endif
    od
  endif
  xout result
endop

opcode MalCoreMaps(name:S, args:MalValue):MalValue
  result:MalValue init MalMkError(sprintf("%s: invalid arguments", name))
  if (strcmp(name, "merge") == 0) ithen
    result init MalMkValue($MAL_NIL_TYPE)
    if (args.length > 0) ithen
      for index in [0 ... args.length - 1] do
        collection:MalValue init MalAt(args, index)
        if (collection.type != $MAL_NIL_TYPE) ithen
          if (collection.type != $MAL_HASH_MAP_TYPE) ithen
            result init MalMkError("merge: expected maps or nil")
            break
          endif
          if (result.type == $MAL_NIL_TYPE) ithen
            result init collection
          elseif (collection.length > 0) ithen
            for pair in [0 ... int(collection.length / 2) - 1] do
              result init MalCoreAssoc(result, MalAt(collection, pair * 2), \
                MalAt(collection, pair * 2 + 1))
            od
          endif
        endif
      od
    endif
  elseif (strcmp(name, "select-keys") == 0 && args.length == 2) ithen
    collection:MalValue init MalAt(args, 0)
    keys:MalValue init MalSeq(MalAt(args, 1))
    result init MalMkValue($MAL_HASH_MAP_TYPE)
    result.metadata init collection.metadata
    if (collection.type != $MAL_HASH_MAP_TYPE && collection.type != $MAL_VECTOR_TYPE && \
        collection.type != $MAL_NIL_TYPE) ithen
      result init MalMkError("select-keys: expected a map, vector, or nil")
    elseif (keys.type == $MAL_ERROR_TYPE) ithen
      result init keys
    elseif (keys.length > 0) ithen
      for index in [0 ... keys.length - 1] do
        key:MalValue init MalAt(keys, index)
        value:MalValue, found:i = MalCoreLookup(collection, key)
        if (found == 1) ithen
          result init MalCoreAssoc(result, key, value)
        endif
      od
    endif
  elseif (strcmp(name, "get-in") == 0 && (args.length == 2 || args.length == 3)) ithen
    path:MalValue init MalSeq(MalAt(args, 1))
    fallback:MalValue init MalMkValue($MAL_NIL_TYPE)
    if (args.length == 3) ithen
      fallback init MalAt(args, 2)
    endif
    if (path.type == $MAL_ERROR_TYPE) ithen
      result init path
    else
      result init MalCoreGetIn(MalAt(args, 0), path, fallback)
    endif
  elseif (strcmp(name, "assoc-in") == 0 && args.length == 3) ithen
    path:MalValue init MalSeq(MalAt(args, 1))
    if (path.type == $MAL_ERROR_TYPE) ithen
      result init path
    else
      result init MalCoreAssocIn(MalAt(args, 0), path, 0, MalAt(args, 2))
    endif
  elseif ((strcmp(name, "update") == 0 || strcmp(name, "update-in") == 0) && args.length >= 3) ithen
    path:MalValue init MalMkList1(MalAt(args, 1))
    if (strcmp(name, "update-in") == 0) ithen
      path init MalSeq(MalAt(args, 1))
      if (path.length == 0 && path.type != $MAL_ERROR_TYPE) ithen
        path init MalMkList1(MalMkValue($MAL_NIL_TYPE))
      endif
    endif
    if (path.type == $MAL_ERROR_TYPE) ithen
      result init path
    else
      old:MalValue init MalCoreGetIn(MalAt(args, 0), path, MalMkValue($MAL_NIL_TYPE))
      callArgs:MalValue init MalMkList1(old)
      if (args.length > 3) ithen
        for index in [3 ... args.length - 1] do
          callArgs init MalAppendValue(callArgs, MalAt(args, index))
        od
      endif
      value:MalValue init old
      if (old.type != $MAL_ERROR_TYPE) ithen
        value init MalApply(MalAt(args, 2), callArgs)
      endif
      if (value.type == $MAL_ERROR_TYPE) ithen
        result init value
      else
        result init MalCoreAssocIn(MalAt(args, 0), path, 0, value)
      endif
    endif
  endif
  xout result
endop

opcode MalCoreLogic(args:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  if (args.length != 2) ithen
    result init MalArityError("core/logic", 2, args.length)
  else
    all:i = MalIsTruthy(MalAt(args, 0))
    forms:MalValue init MalAt(args, 1)
    if (forms.type != $MAL_LIST_TYPE && forms.type != $MAL_VECTOR_TYPE && \
        forms.type != $MAL_NIL_TYPE) ithen
      result init MalMkError("core/logic: expected a sequence")
    elseif (forms.length == 0) ithen
      if (all == 1) ithen
        result init MalMkValue($MAL_TRUE_TYPE)
      endif
    else
      result init MalAt(forms, forms.length - 1)
      if (forms.length > 1) ithen
        firstId:i = malGensymCount + 1
        malGensymCount += forms.length - 1
        for offset in [0 ... forms.length - 2] do
          index:i = forms.length - offset - 2
          name:MalValue init MalMkSymbol(sprintf("G__%.0f", firstId + index))
          if (all == 1) ithen
            branch:MalValue init MalAppendValue(MalMkList3(MalMkSymbol("if"), name, result), name)
          else
            branch:MalValue init MalAppendValue(MalMkList3(MalMkSymbol("if"), name, name), result)
          endif
          result init MalMkList3(MalMkSymbol("let*"), \
            MalMkList2(name, MalAt(forms, index)), branch)
        od
      endif
    endif
  endif
  xout result
endop

opcode MalApplyCoreBuiltin(fn:MalValue, args:MalValue):MalValue
  name:S init fn.string
  result:MalValue init MalMkError(sprintf("unknown builtin '%s'", name))
  if (strcmp(name, "core/logic") == 0) ithen
    result init MalCoreLogic(args)
  elseif (strcmp(name, "reduce") == 0) ithen
    result init MalCoreReduce(args)
  elseif (strcmp(name, "mapv") == 0) ithen
    result init MalCoreMap(name, args, $MAL_VECTOR_TYPE)
  elseif (strcmp(name, "range") == 0) ithen
    result init MalCoreRange(args)
  elseif (strcmp(name, "min") == 0 || strcmp(name, "max") == 0) ithen
    result init MalCoreExtremum(name, args)
  elseif (strcmp(name, "mod") == 0 || strcmp(name, "quot") == 0 || strcmp(name, "rem") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(name, 2, args.length)
    else
      dividend:MalValue init MalAt(args, 0)
      divisor:MalValue init MalAt(args, 1)
      if (dividend.type != $MAL_NUMBER_TYPE || divisor.type != $MAL_NUMBER_TYPE) ithen
        result init MalMkError(sprintf("%s: expected numeric arguments", name))
      elseif (divisor.number == 0) ithen
        result init MalMkError(sprintf("%s: division by zero", name))
      elseif (strcmp(name, "quot") == 0) ithen
        quotient:i = dividend.number / divisor.number
        result init MalMkNumber(quotient < 0 ? ceil(quotient) : floor(quotient))
      else
        ;; Csound's remainder follows the dividend. mod follows the divisor.
        remainder:i = dividend.number % divisor.number
        if (strcmp(name, "mod") == 0 && ((remainder < 0 && divisor.number > 0) || \
            (remainder > 0 && divisor.number < 0))) ithen
          remainder += divisor.number
        endif
        result init MalMkNumber(remainder)
      endif
    endif
  elseif (strcmp(name, "filter") == 0 || strcmp(name, "filterv") == 0 || \
          strcmp(name, "remove") == 0 || strcmp(name, "keep") == 0 || \
          strcmp(name, "every?") == 0 || strcmp(name, "not-every?") == 0 || \
          strcmp(name, "some") == 0 || strcmp(name, "not-any?") == 0 || \
          strcmp(name, "take-while") == 0 || strcmp(name, "drop-while") == 0) ithen
    result init MalCoreSelect(name, args)
  elseif (strcmp(name, "get-in") == 0 || strcmp(name, "assoc-in") == 0 || \
          strcmp(name, "update") == 0 || strcmp(name, "update-in") == 0 || \
          strcmp(name, "select-keys") == 0 || strcmp(name, "merge") == 0) ithen
    result init MalCoreMaps(name, args)
  elseif (strcmp(name, "not=") == 0) ithen
    if (args.length == 0) ithen
      result init MalMkError("not=: expected at least 1 argument")
    else
      equal:i = 1
      if (args.length > 1) ithen
        for index in [1 ... args.length - 1] do
          if (MalEquals(MalAt(args, 0), MalAt(args, index)) == 0) ithen
            equal = 0
            break
          endif
        od
      endif
      result init MalMkBool(equal == 0 ? 1 : 0)
    endif
  elseif (strcmp(name, "take") == 0 || strcmp(name, "drop") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(name, 2, args.length)
    else
      amount:MalValue init MalAt(args, 0)
      sequence:MalValue init MalSeq(MalAt(args, 1))
      if (amount.type != $MAL_NUMBER_TYPE) ithen
        result init MalMkError(sprintf("%s: count must be a number", name))
      elseif (sequence.type == $MAL_ERROR_TYPE) ithen
        result init sequence
      else
        size:i = min(sequence.length, max(0, ceil(amount.number)))
        start:i = strcmp(name, "take") == 0 ? 0 : size
        end:i = strcmp(name, "take") == 0 ? size : sequence.length
        result init MalCoreSlice(sequence, start, end, 0)
      endif
    endif
  elseif (strcmp(name, "identity") == 0 || strcmp(name, "boolean") == 0 || \
          strcmp(name, "some?") == 0 || strcmp(name, "inc") == 0 || \
          strcmp(name, "dec") == 0 || strcmp(name, "abs") == 0 || strcmp(name, "zero?") == 0 || \
          strcmp(name, "pos?") == 0 || strcmp(name, "neg?") == 0 || \
          strcmp(name, "reduced") == 0 || strcmp(name, "reduced?") == 0 || \
          strcmp(name, "ensure-reduced") == 0 || strcmp(name, "unreduced") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(name, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      if (strcmp(name, "identity") == 0) ithen
        result init value
      elseif (strcmp(name, "boolean") == 0) ithen
        result init MalMkBool(MalIsTruthy(value))
      elseif (strcmp(name, "some?") == 0) ithen
        result init MalMkBool(value.type != $MAL_NIL_TYPE ? 1 : 0)
      elseif (strcmp(name, "reduced?") == 0) ithen
        result init MalMkBool(value.type == $MAL_REDUCED_TYPE ? 1 : 0)
      elseif (strcmp(name, "unreduced") == 0) ithen
        result init value
        if (value.type == $MAL_REDUCED_TYPE) ithen
          result init MalAt(value, 0)
        endif
      elseif (strcmp(name, "reduced") == 0 || strcmp(name, "ensure-reduced") == 0) ithen
        result init value
        if (value.type != $MAL_REDUCED_TYPE || strcmp(name, "reduced") == 0) ithen
          result init MalMkList1(value)
          result.type = $MAL_REDUCED_TYPE
          result.number = malReducedCount
          malReducedCount += 1
        endif
      elseif (MalIsCsoundNode(value) == 1 && \
              (strcmp(name, "inc") == 0 || strcmp(name, "dec") == 0)) ithen
        operator:S init strcmp(name, "inc") == 0 ? "+" : "-"
        result init MalMkCsoundInfix(operator, MalMkList2(value, MalMkNumber(1)))
      elseif (value.type != $MAL_NUMBER_TYPE) ithen
        result init MalMkError(sprintf("%s: expected a number", name))
      elseif (strcmp(name, "inc") == 0) ithen
        result init MalMkNumber(value.number + 1)
      elseif (strcmp(name, "dec") == 0) ithen
        result init MalMkNumber(value.number - 1)
      elseif (strcmp(name, "abs") == 0) ithen
        result init MalMkNumber(abs(value.number))
      elseif (strcmp(name, "zero?") == 0) ithen
        result init MalMkBool(value.number == 0 ? 1 : 0)
      elseif (strcmp(name, "pos?") == 0) ithen
        result init MalMkBool(value.number > 0 ? 1 : 0)
      else
        result init MalMkBool(value.number < 0 ? 1 : 0)
      endif
    endif
  elseif (strcmp(name, "next") == 0 || strcmp(name, "second") == 0 || \
          strcmp(name, "last") == 0 || strcmp(name, "butlast") == 0 || \
          strcmp(name, "reverse") == 0 || strcmp(name, "not-empty") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(name, 1, args.length)
    else
      original:MalValue init MalAt(args, 0)
      sequence:MalValue init MalMkValue($MAL_NIL_TYPE)
      directArrayRead:i = MalIsCsoundArray(original) == 1 && \
        (strcmp(name, "second") == 0 || strcmp(name, "last") == 0)
      if (directArrayRead == 0) ithen
        sequence init MalSeq(original)
      endif
      result init MalMkValue($MAL_NIL_TYPE)
      if (directArrayRead == 1) ithen
        arrayIndex:MalValue init MalMkNumber(1)
        if (strcmp(name, "last") == 0) ithen
          size:i = MalCsoundArraySize(original)
          if (size >= 0) ithen
            arrayIndex init MalMkNumber(size - 1)
          else
            arrayIndex init MalMkCsoundInfix("-", MalMkList2(MalCsoundArrayCount(original), MalMkNumber(1)))
          endif
        endif
        result init MalCsoundArrayRead(original, arrayIndex, name)
      elseif (sequence.type == $MAL_ERROR_TYPE) ithen
        result init sequence
      elseif (strcmp(name, "not-empty") == 0) ithen
        if (sequence.length > 0) ithen
          result init original
        endif
      elseif (strcmp(name, "second") == 0) ithen
        if (sequence.length > 1) ithen
          result init MalAt(sequence, 1)
        endif
      elseif (strcmp(name, "last") == 0) ithen
        if (sequence.length > 0) ithen
          result init MalAt(sequence, sequence.length - 1)
        endif
      elseif (strcmp(name, "reverse") == 0) ithen
        result init MalCoreSlice(sequence, 0, sequence.length, 1)
      elseif (sequence.length > 1) ithen
        if (strcmp(name, "next") == 0) ithen
          result init MalCoreSlice(sequence, 1, sequence.length, 0)
        else
          result init MalCoreSlice(sequence, 0, sequence.length - 1, 0)
        endif
      endif
    endif
  endif
  xout result
endop

;; Step A adds Clojure arities without changing the earlier MAL lessons.
opcode MalMkClojureBuiltin(name:S):MalValue
  result:MalValue init MalMkBuiltin(name)
  result.number = 1
  xout result
endop

opcode MalInstallCoreHelpers(env:MalEnv):MalEnv
  currentEnv:MalEnv init env
  currentEnv init MalEnvSet(currentEnv, "get", MalMkClojureBuiltin("get"))
  currentEnv init MalEnvSet(currentEnv, "nth", MalMkClojureBuiltin("nth"))
  currentEnv init MalEnvSet(currentEnv, "map", MalMkClojureBuiltin("map"))
  names:S[] fillarray "identity", "inc", "dec", "mod", "rem", "quot", "abs", "min", "max", "range", \
    "zero?", "pos?", "neg?", \
    "some?", "boolean", "not=", "next", "second", "last", "butlast", \
    "reverse", "not-empty", "reduce", "reduced", "reduced?", "ensure-reduced", \
    "unreduced", "filter", "remove", "keep", "mapv", "filterv", "every?", \
    "not-every?", "some", "not-any?", "take", "drop", "take-while", \
    "drop-while", "get-in", "assoc-in", "update", "update-in", "select-keys", "merge", "core/logic"
  for name in names do
    currentEnv init MalEnvSet(currentEnv, name, MalMkBuiltin(name))
  od
  source:S init {{
(do
  (defn constantly [value] (fn* (& args) value))
  (defn complement [f] (fn* (& args) (not (apply f args))))
  (defn partial [f & bound]
    (if (empty? bound) f
        (fn* (& args) (apply f (concat bound args)))))
  (defn comp [& functions]
    (if (empty? functions) identity
        (if (= (count functions) 1) (first functions)
            (let* [ordered (reverse functions)]
              (fn* (& args)
                ;; Keep reduced values as data so every function runs.
                (first
                  (reduce (fn* (value f) (list (f (first value))))
                          (list (apply (first ordered) args))
                          (rest ordered))))))))
  (defn juxt [f & functions]
    (let* [all (cons f functions)]
      (fn* (& args) (mapv (fn* (g) (apply g args)) all))))

  (defmacro and [& forms] (core/logic true forms))
  (defmacro or [& forms] (core/logic false forms))
  (defmacro if-not [test then & otherwise]
    (if (> (count otherwise) 1) (throw "if-not: expected 2 or 3 arguments")
        (list 'if test (first otherwise) then)))
  (defmacro when [test & body] (list 'if test (cons 'do body) nil))
  (defmacro when-not [test & body] (list 'if test nil (cons 'do body)))
  (defmacro comment [& forms] nil)
  (defmacro assert [test & message]
    (if (> (count message) 1) (throw "assert: expected 1 or 2 arguments")
        (list 'if test nil
              (list throw
                    (if (empty? message)
                        (str "Assert failed: " (pr-str test))
                        (list str "Assert failed: " (first message) "\n" (pr-str test)))))))

  (defn core/binding [bindings then else nil-only?]
    (if (and (vector? bindings) (= (count bindings) 2)
             (or (symbol? (first bindings)) (vector? (first bindings)) (map? (first bindings))))
      (let* [name (gensym)
             pattern (first bindings)
             body (if (symbol? pattern)
                    (list 'let* (list pattern name) then)
                    (list 'let (vector pattern name) then))]
        (list 'let (vector name (nth bindings 1))
              (if nil-only?
                (list 'if (list nil? name) else body)
                (list 'if name body else))))
      (throw "conditional binding requires [pattern expression]")))
  (defmacro if-let [bindings then & otherwise]
    (if (> (count otherwise) 1) (throw "if-let: expected 2 or 3 arguments")
        (core/binding bindings then (first otherwise) false)))
  (defmacro if-some [bindings then & otherwise]
    (if (> (count otherwise) 1) (throw "if-some: expected 2 or 3 arguments")
        (core/binding bindings then (first otherwise) true)))
  (defmacro when-let [bindings & body] (core/binding bindings (cons 'do body) nil false))
  (defmacro when-some [bindings & body] (core/binding bindings (cons 'do body) nil true)))
}}
  result:MalValue, currentEnv = MalEvalSourceEnv(source, currentEnv)
  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "core helper bootstrap failed: %s\n", result.string
  endif
  xout currentEnv
endop
