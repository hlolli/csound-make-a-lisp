;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

declare EVAL_ENV(result:MalValue, nextEnv:MalEnv):(MalValue, MalEnv)
declare MalEquals(left:MalValue, right:MalValue):(i)
declare MalApply(fn:MalValue, args:MalValue):(MalValue)
declare MalQuasiquote(ast:MalValue):(MalValue)
declare MalEvalSourceEnv(source:S, env:MalEnv):(MalValue, MalEnv)

opcode MalApplyBuiltinOperator(fn:MalValue, args:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NUMBER_TYPE)

  if (args.length != 2) ithen
    result init MalMkError(sprintf("%s: expected 2 arguments, got %d", \
      fn.string, args.length))
  else
    leftArg:MalValue init MalAt(args, 0)
    rightArg:MalValue init MalAt(args, 1)

    if (MalIsCsoundNode(leftArg) == 1 || MalIsCsoundNode(rightArg) == 1) ithen
      leftIsGraphValue:i = leftArg.type == $MAL_NUMBER_TYPE || \
        MalIsCsoundNode(leftArg) == 1
      rightIsGraphValue:i = rightArg.type == $MAL_NUMBER_TYPE || \
        MalIsCsoundNode(rightArg) == 1

      if (leftIsGraphValue == 0 || rightIsGraphValue == 0) ithen
        result init MalMkError(sprintf( \
          "%s: expected numeric or Csound graph arguments", fn.string))
      else
        result init MalMkCsoundInfix(fn.string, args)
      endif
    elseif (leftArg.type != $MAL_NUMBER_TYPE || \
            rightArg.type != $MAL_NUMBER_TYPE) ithen
      result init MalMkError(sprintf("%s: expected numeric arguments", fn.string))
    else
      left:i = leftArg.number
      right:i = rightArg.number

      if (strlen(fn.string) != 1) ithen
        result init MalMkError(sprintf("unknown builtin operator '%s'", fn.string))
      else
        iop = strchar:i(fn.string, 0)

        switch iop
          case $MAL_PLUS_TOKEN
            result.number = left + right

          case $MAL_MINUS_TOKEN
            result.number = left - right

          case $MAL_STAR_TOKEN
            result.number = left * right

          case $MAL_SLASH_TOKEN
            if (right == 0) ithen
              result init MalMkError("/: division by zero")
            else
              result.number = int(left / right)
            endif

          default
            result init MalMkError(sprintf("unknown builtin operator '%s'", fn.string))
        endsw
      endif
    endif
  endif

  xout result
endop

opcode MalMkBool(condition:i):MalValue
  if (condition == 0) ithen
    result:MalValue init MalMkValue($MAL_FALSE_TYPE)
  else
    result:MalValue init MalMkValue($MAL_TRUE_TYPE)
  endif

  xout result
endop

opcode MalIsTruthy(value:MalValue):i
  result:i = 1

  if (value.type == $MAL_NIL_TYPE || value.type == $MAL_FALSE_TYPE) ithen
    result = 0
  endif

  xout result
endop

opcode MalIsSymbolNamed(value:MalValue, name:S):i
  result:i = (value.type == $MAL_SYMBOL_TYPE && \
    strcmp(value.string, name) == 0)
  xout result
endop

opcode MalIsForm(ast:MalValue, name:S):i
  result:i = 0

  if (ast.type == $MAL_LIST_TYPE && ast.length > 0) ithen
    head:MalValue init MalAt(ast, 0)
    result init MalIsSymbolNamed(head, name)
  endif

  xout result
endop

opcode MalIsSequential(value:MalValue):i
  result:i = (value.type == $MAL_LIST_TYPE || \
    value.type == $MAL_VECTOR_TYPE)
  xout result
endop

opcode MalCopySequenceAs(value:MalValue, resultType:i):MalValue
  values:MalValue[] init value.length

  if (value.length > 0) ithen
    for index in [0 ... value.length - 1] do
      values[index] init MalAt(value, index)
    od
  endif

  result:MalValue init MalMkValue(resultType)
  result.list init values
  result.length = value.length
  xout result
endop

opcode MalFlattenApplyArgs(args:MalValue):MalValue
  finalSequence:MalValue init MalAt(args, args.length - 1)
  prefixLength:i = args.length - 2
  flattenedLength:i = prefixLength + finalSequence.length
  values:MalValue[] init flattenedLength

  if (prefixLength > 0) ithen
    for index in [0 ... prefixLength - 1] do
      values[index] init MalAt(args, index + 1)
    od
  endif

  if (finalSequence.length > 0) ithen
    for index in [0 ... finalSequence.length - 1] do
      values[prefixLength + index] init MalAt(finalSequence, index)
    od
  endif

  result:MalValue init MalMkValue($MAL_LIST_TYPE)
  result.list init values
  result.length = flattenedLength
  xout result
endop

opcode MalMapSequence(fn:MalValue, sequence:MalValue):MalValue
  values:MalValue[] init sequence.length
  result:MalValue init MalMkValue($MAL_LIST_TYPE)
  failed:i = 0

  if (sequence.length > 0) ithen
    for index in [0 ... sequence.length - 1] do
      callArgs:MalValue init MalMkList1(MalAt(sequence, index))
      mapped:MalValue init MalApply(fn, callArgs)

      if (mapped.type == $MAL_ERROR_TYPE) ithen
        result init mapped
        failed = 1
        break
      endif

      values[index] init mapped
    od
  endif

  if (failed == 0) ithen
    result.list init values
    result.length = sequence.length
  endif

  xout result
endop

opcode MalAssocPairs(mapValue:MalValue, args:MalValue, startIndex:i):MalValue
  result:MalValue init mapValue
  pairCount:i = int((args.length - startIndex) / 2)

  if (pairCount > 0) ithen
    for pairIndex in [0 ... pairCount - 1] do
      keyIndex:i = startIndex + pairIndex * 2
      result init MalMapAssoc( \
        result, MalAt(args, keyIndex), MalAt(args, keyIndex + 1))
    od
  endif

  xout result
endop

opcode MalDissocKeys(mapValue:MalValue, args:MalValue):MalValue
  result:MalValue init mapValue
  if (args.length > 1) ithen
    for index in [1 ... args.length - 1] do
      result init MalMapDissoc(result, MalAt(args, index))
    od
  endif

  xout result
endop

opcode MalJoinPrintedArgs(args:MalValue, printReadably:i, separator:S):S
  output:S init ""

  if (args.length > 0) ithen
    for index in [0 ... args.length - 1] do
      if (index > 0) ithen
        output strcat output, separator
      endif

      output strcat output, \
        pr_str_with_readability(MalAt(args, index), printReadably)
    od
  endif

  xout output
endop

opcode MalArityError(name:S, expected:i, actual:i):MalValue
  result:MalValue init MalMkError(sprintf("%s: expected %d arguments, got %d", \
    name, expected, actual))
  xout result
endop

opcode MalApplyTypePredicate(fn:MalValue, args:MalValue, expectedType:i):MalValue
  if (args.length != 1) ithen
    result:MalValue init MalArityError(fn.string, 1, args.length)
  else
    value:MalValue init MalAt(args, 0)
    matches:i = value.type == expectedType
    result:MalValue init MalMkBool(matches)
  endif

  xout result
endop

opcode MalNumberComparison(name:S, left:i, right:i):i
  result:i = 0

  if (strcmp(name, ">") == 0) ithen
    result = left > right
  elseif (strcmp(name, ">=") == 0) ithen
    result = left >= right
  elseif (strcmp(name, "<") == 0) ithen
    result = left < right
  elseif (strcmp(name, "<=") == 0) ithen
    result = left <= right
  endif

  xout result
endop

opcode MalApplyNumericComparison(fn:MalValue, args:MalValue):MalValue
  if (args.length != 2) ithen
    result:MalValue init MalArityError(fn.string, 2, args.length)
  else
    leftArg:MalValue init MalAt(args, 0)
    rightArg:MalValue init MalAt(args, 1)

    if (leftArg.type != $MAL_NUMBER_TYPE || \
        rightArg.type != $MAL_NUMBER_TYPE) ithen
      result:MalValue init MalMkError(sprintf("%s: expected numeric arguments", \
        fn.string))
    else
      comparison:i = MalNumberComparison(fn.string, leftArg.number, rightArg.number)
      result:MalValue init MalMkBool(comparison)
    endif
  endif

  xout result
endop

opcode MalIsFn(value:MalValue):i
  result:i = 0

  switch value.type
    case $MAL_BUILTIN_TYPE
      result = 1

    case $MAL_BUILTIN_OPERATOR_TYPE
      result = 1

    case $MAL_BUILTIN_OPCODE_TYPE
      result = 1

    case $MAL_FUNCTION_TYPE
      result = value.isMacro == 0

    case $MAL_CSOUND_INSTRUMENT_TYPE
      result = 1
  endsw

  xout result
endop

opcode MalSeq(value:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)

  switch value.type
    case $MAL_NIL_TYPE
      result init value
    case $MAL_LIST_TYPE
      if (value.length > 0) ithen
        result init value
      endif

    case $MAL_VECTOR_TYPE
      if (value.length > 0) ithen
        result init MalCopySequenceAs(value, $MAL_LIST_TYPE)
      endif

    case $MAL_HASH_MAP_TYPE
      pairCount:i = int(value.length / 2)
      if (pairCount > 0) ithen
        entries:MalValue[] init pairCount
        for index in [0 ... pairCount - 1] do
          entry:MalValue init MalMkList2(MalAt(value, index * 2), MalAt(value, index * 2 + 1))
          entry.type = $MAL_VECTOR_TYPE
          entries[index] init entry
        od
        result init MalMkValue($MAL_LIST_TYPE)
        result.list init entries
        result.length = pairCount
      endif

    case $MAL_STRING_TYPE
      characterCount:i = strlen(value.string)

      if (characterCount > 0) ithen
        characters:MalValue[] init characterCount

        for index in [0 ... characterCount - 1] do
          character:S init strsub(value.string, index, index + 1)
          characters[index] init MalMkString(character)
        od

        result init MalMkValue($MAL_LIST_TYPE)
        result.list init characters
        result.length = characterCount
      endif

    default
      result init MalMkError("seq: expected list, vector, map, string, or nil")
  endsw

  xout result
endop

opcode MalConj(args:MalValue):MalValue
  collection:MalValue init MalAt(args, 0)
  addedCount:i = args.length - 1
  resultLength:i = collection.length + addedCount
  values:MalValue[] init resultLength
  result:MalValue init MalMkValue(collection.type)

  if (collection.type == $MAL_LIST_TYPE) ithen
    for index in [0 ... addedCount - 1] do
      values[index] init MalAt(args, args.length - index - 1)
    od

    if (collection.length > 0) ithen
      for index in [0 ... collection.length - 1] do
        values[addedCount + index] init MalAt(collection, index)
      od
    endif

  elseif (collection.type == $MAL_VECTOR_TYPE) ithen
    if (collection.length > 0) ithen
      for index in [0 ... collection.length - 1] do
        values[index] init MalAt(collection, index)
      od
    endif

    for index in [0 ... addedCount - 1] do
      values[collection.length + index] init MalAt(args, index + 1)
    od
  endif

  result.list init values
  result.length = resultLength
  xout result
endop

opcode MalSlurpFile(filename:S):MalValue
  content:S init ""
  line:S init ""
  lineNumber:i = 0

read_line:
  line, lineNumber readfi filename

  if (lineNumber != -1) ithen
    content strcat content, line
    igoto read_line
  endif

  result:MalValue MalMkString content
  xout result
endop

opcode MalEquals(left:MalValue, right:MalValue):i
  result:i = 0
  leftIsSequence:i = 0
  rightIsSequence:i = 0

  if (left.type == $MAL_LIST_TYPE || left.type == $MAL_VECTOR_TYPE) ithen
    leftIsSequence = 1
  endif

  if (right.type == $MAL_LIST_TYPE || right.type == $MAL_VECTOR_TYPE) ithen
    rightIsSequence = 1
  endif

  if (leftIsSequence == 1 && rightIsSequence == 1) ithen
    if (left.length == right.length) ithen
      result = 1

      if (left.length > 0) ithen
        for index in [0 ... left.length - 1] do
          leftItem:MalValue init MalAt(left, index)
          rightItem:MalValue init MalAt(right, index)

          if (MalEquals(leftItem, rightItem) == 0) ithen
            result = 0
            break
          endif
        od
      endif
    endif
  elseif (left.type == $MAL_HASH_MAP_TYPE && \
          right.type == $MAL_HASH_MAP_TYPE) ithen
    if (left.length == right.length) ithen
      result = 1
      entryCount:i = int(left.length / 2)

      if (entryCount > 0) ithen
        for entryIndex in [0 ... entryCount - 1] do
          leftKeyIndex:i = entryIndex * 2
          rightKeyIndex:i = MalMapFindKey( \
            right, MalAt(left, leftKeyIndex))

          if (rightKeyIndex < 0) ithen
            result = 0
            break
          else
            leftValue:MalValue init MalAt(left, leftKeyIndex + 1)
            rightValue:MalValue init MalAt(right, rightKeyIndex + 1)

            if (MalEquals(leftValue, rightValue) == 0) ithen
              result = 0
              break
            endif
          endif
        od
      endif
    endif
  elseif (left.type == right.type) ithen
    switch left.type
      case $MAL_NUMBER_TYPE
        result = left.number == right.number

      case $MAL_STRING_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_KEYWORD_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_SYMBOL_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_NIL_TYPE
        result = 1

      case $MAL_TRUE_TYPE
        result = 1

      case $MAL_FALSE_TYPE
        result = 1

      case $MAL_ATOM_TYPE
        result = left.number == right.number

      case $MAL_REDUCED_TYPE
        result = left.number == right.number
    endsw
  endif

  xout result
endop

#include "src/core.orc"

opcode MalApplyBuiltin(fn:MalValue, args:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)

  if (strcmp(fn.string, "throw") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalMkThrown(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "apply") == 0) ithen
    if (args.length < 2) ithen
      result init MalMkError(sprintf( \
        "apply: expected at least 2 arguments, got %d", args.length))
    else
      targetFn:MalValue init MalAt(args, 0)
      finalSequence:MalValue init MalAt(args, args.length - 1)

      if (MalIsSequential(finalSequence) == 0) ithen
        result init MalMkError( \
          "apply: final argument must be list or vector")
      else
        flattenedArgs:MalValue init MalFlattenApplyArgs(args)
        result init MalApply(targetFn, flattenedArgs)
      endif
    endif

  elseif (strcmp(fn.string, "map") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      targetFn:MalValue init MalAt(args, 0)
      sequence:MalValue init MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) ithen
        result init MalMkError("map: second argument must be list or vector")
      else
        result init MalMapSequence(targetFn, sequence)
      endif
    endif

  elseif (strcmp(fn.string, "nil?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_NIL_TYPE)

  elseif (strcmp(fn.string, "true?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_TRUE_TYPE)

  elseif (strcmp(fn.string, "false?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_FALSE_TYPE)

  elseif (strcmp(fn.string, "symbol?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_SYMBOL_TYPE)

  elseif (strcmp(fn.string, "string?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_STRING_TYPE)

  elseif (strcmp(fn.string, "number?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_NUMBER_TYPE)

  elseif (strcmp(fn.string, "fn?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalMkBool(MalIsFn(MalAt(args, 0)))
    endif

  elseif (strcmp(fn.string, "symbol") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) ithen
        result init MalMkError("symbol: expected string argument")
      else
        result init MalMkSymbol(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "gensym") == 0) ithen
    if (args.length > 1) ithen
      result init MalMkError("gensym: expected zero or one argument")
    else
      prefix:S init "G__"
      valid:i = 1

      if (args.length == 1) ithen
        value:MalValue init MalAt(args, 0)
        if (value.type != $MAL_STRING_TYPE) ithen
          valid = 0
        else
          prefix = value.string
        endif
      endif

      if (valid == 0) ithen
        result init MalMkError("gensym: prefix must be a string")
      else
        malGensymCount += 1
        result init MalMkSymbol(sprintf("%s%.0f", prefix, malGensymCount))
      endif
    endif

  elseif (strcmp(fn.string, "keyword") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)

      if (value.type == $MAL_KEYWORD_TYPE) ithen
        result init value
      elseif (value.type == $MAL_STRING_TYPE) ithen
        result init MalMkKeyword(value.string)
      else
        result init MalMkError("keyword: expected string or keyword argument")
      endif
    endif

  elseif (strcmp(fn.string, "keyword?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_KEYWORD_TYPE)

  elseif (strcmp(fn.string, "list") == 0) ithen
    result init args
  elseif (strcmp(fn.string, "vector") == 0) ithen
    result init MalCopySequenceAs(args, $MAL_VECTOR_TYPE)

  elseif (strcmp(fn.string, "vector?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_VECTOR_TYPE)

  elseif (strcmp(fn.string, "sequential?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      isSequential:i = MalIsSequential(value)
      result init MalMkBool(isSequential)
    endif

  elseif (strcmp(fn.string, "hash-map") == 0) ithen
    if (args.length % 2 != 0) ithen
      result init MalMkError("hash-map: expected even number of arguments")
    else
      emptyMap:MalValue init MalMkValue($MAL_HASH_MAP_TYPE)
      result init MalAssocPairs(emptyMap, args, 0)
    endif

  elseif (strcmp(fn.string, "map?") == 0) ithen
    result init MalApplyTypePredicate(fn, args, $MAL_HASH_MAP_TYPE)

  elseif (strcmp(fn.string, "assoc") == 0) ithen
    if (args.length < 1) ithen
      result init MalMkError("assoc: expected at least 1 argument, got 0")
    else
      mapValue:MalValue init MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("assoc: first argument must be a hash map")
      elseif ((args.length - 1) % 2 != 0) ithen
        result init MalMkError("assoc: expected key/value pairs")
      else
        result init MalAssocPairs(mapValue, args, 1)
      endif
    endif

  elseif (strcmp(fn.string, "dissoc") == 0) ithen
    if (args.length < 1) ithen
      result init MalMkError("dissoc: expected at least 1 argument, got 0")
    else
      mapValue:MalValue init MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("dissoc: first argument must be a hash map")
      else
        result init MalDissocKeys(mapValue, args)
      endif
    endif

  elseif (strcmp(fn.string, "get") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      mapValue:MalValue init MalAt(args, 0)
      key:MalValue init MalAt(args, 1)

      if (mapValue.type == $MAL_NIL_TYPE) ithen
        result init MalMkValue($MAL_NIL_TYPE)
      elseif (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("get: first argument must be a hash map or nil")
      else
        result init MalMapGet(mapValue, key)
      endif
    endif

  elseif (strcmp(fn.string, "contains?") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      mapValue:MalValue init MalAt(args, 0)
      key:MalValue init MalAt(args, 1)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("contains?: first argument must be a hash map")
      else
        found:i = MalMapFindKey(mapValue, key) >= 0
        result init MalMkBool(found)
      endif
    endif

  elseif (strcmp(fn.string, "keys") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      mapValue:MalValue init MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("keys: expected hash map argument")
      else
        result init MalMapKeys(mapValue)
      endif
    endif

  elseif (strcmp(fn.string, "vals") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      mapValue:MalValue init MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) ithen
        result init MalMkError("vals: expected hash map argument")
      else
        result init MalMapValues(mapValue)
      endif
    endif

  elseif (strcmp(fn.string, "meta") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalMeta(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "with-meta") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      result init MalWithMeta(MalAt(args, 0), MalAt(args, 1))
    endif

  elseif (strcmp(fn.string, "cons") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      first:MalValue init MalAt(args, 0)
      sequence:MalValue init MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) ithen
        result init MalMkError("cons: second argument must be list or vector")
      else
        resultLength:i = sequence.length + 1
        values:MalValue[] init resultLength
        values[0] init first

        if (sequence.length > 0) ithen
          for index in [0 ... sequence.length - 1] do
            values[index + 1] init MalAt(sequence, index)
          od
        endif

        result init MalMkValue($MAL_LIST_TYPE)
        result.list init values
        result.length = resultLength
      endif
    endif

  elseif (strcmp(fn.string, "concat") == 0) ithen
    totalLength:i = 0
    valid:i = 1

    if (args.length > 0) ithen
      for index in [0 ... args.length - 1] do
        sequence:MalValue init MalAt(args, index)

        if (MalIsSequential(sequence) == 0) ithen
          valid = 0
          break
        endif

        totalLength += sequence.length
      od
    endif

    if (valid == 0) ithen
      result init MalMkError("concat: expected list or vector arguments")
    else
      values:MalValue[] init totalLength
      destinationIndex:i = 0

      if (args.length > 0) ithen
        for sequenceIndex in [0 ... args.length - 1] do
          sequence:MalValue init MalAt(args, sequenceIndex)

          if (sequence.length > 0) ithen
            for valueIndex in [0 ... sequence.length - 1] do
              values[destinationIndex] init MalAt(sequence, valueIndex)
              destinationIndex += 1
            od
          endif
        od
      endif

      result init MalMkValue($MAL_LIST_TYPE)
      result.list init values
      result.length = totalLength
    endif

  elseif (strcmp(fn.string, "vec") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue init MalAt(args, 0)

      if (MalIsSequential(sequence) == 0) ithen
        result init MalMkError("vec: expected list or vector argument")
      else
        result init MalCopySequenceAs(sequence, $MAL_VECTOR_TYPE)
      endif
    endif

  elseif (strcmp(fn.string, "nth") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      sequence:MalValue init MalAt(args, 0)
      indexValue:MalValue init MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) ithen
        result init MalMkError("nth: first argument must be list or vector")
      elseif (indexValue.type != $MAL_NUMBER_TYPE) ithen
        result init MalMkError("nth: index must be a number")
      elseif (indexValue.number != int(indexValue.number)) ithen
        result init MalMkError("nth: index must be an integer")
      elseif (indexValue.number < 0 || indexValue.number >= sequence.length) ithen
        result init MalMkError("nth: index out of range")
      else
        index:i = indexValue.number
        result init MalAt(sequence, index)
      endif
    endif

  elseif (strcmp(fn.string, "first") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue init MalAt(args, 0)

      if (sequence.type == $MAL_NIL_TYPE || \
          (MalIsSequential(sequence) == 1 && sequence.length == 0)) ithen
        result init MalMkValue($MAL_NIL_TYPE)
      elseif (MalIsSequential(sequence) == 0) ithen
        result init MalMkError("first: expected list, vector, or nil")
      else
        result init MalAt(sequence, 0)
      endif
    endif

  elseif (strcmp(fn.string, "rest") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue init MalAt(args, 0)

      if (sequence.type != $MAL_NIL_TYPE && MalIsSequential(sequence) == 0) ithen
        result init MalMkError("rest: expected list, vector, or nil")
      else
        result init MalMkValue($MAL_LIST_TYPE)

        if (sequence.type != $MAL_NIL_TYPE && sequence.length > 1) ithen
          restLength:i = sequence.length - 1
          values:MalValue[] init restLength

          for index in [0 ... restLength - 1] do
            values[index] init MalAt(sequence, index + 1)
          od

          result.list init values
          result.length = restLength
        endif
      endif
    endif

  elseif (strcmp(fn.string, "seq") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalSeq(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "conj") == 0) ithen
    if (args.length < 2) ithen
      result init MalMkError(sprintf( \
        "conj: expected at least 2 arguments, got %d", args.length))
    else
      collection:MalValue init MalAt(args, 0)

      if (MalIsSequential(collection) == 0) ithen
        result init MalMkError("conj: first argument must be list or vector")
      else
        result init MalConj(args)
      endif
    endif

  elseif (strcmp(fn.string, "list?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      result init MalMkBool(value.type == $MAL_LIST_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "empty?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      isEmpty:i = value.type == $MAL_NIL_TYPE || \
        value.type == $MAL_LIST_TYPE && value.length == 0 || \
        value.type == $MAL_VECTOR_TYPE && value.length == 0 || \
        value.type == $MAL_HASH_MAP_TYPE && value.length == 0
      result init MalMkBool(isEmpty)
    endif

  elseif (strcmp(fn.string, "count") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      result init MalMkValue($MAL_NUMBER_TYPE)

      if (value.type == $MAL_NIL_TYPE) ithen
        result.number = 0
      elseif (value.type == $MAL_LIST_TYPE || \
              value.type == $MAL_VECTOR_TYPE) ithen
        result.number = value.length
      elseif (value.type == $MAL_HASH_MAP_TYPE) ithen
        result.number = int(value.length / 2)
      else
        result init MalMkError("count: expected sequence or nil")
      endif
    endif

  elseif (strcmp(fn.string, "str") == 0) ithen
    result init MalMkString(MalJoinPrintedArgs(args, 0, ""))

  elseif (strcmp(fn.string, "pr-str") == 0) ithen
    result init MalMkString(MalJoinPrintedArgs(args, 1, " "))

  elseif (strcmp(fn.string, "println") == 0) ithen
    output:S init MalJoinPrintedArgs(args, 0, " ")
    prints "%s\n", output
    result init MalMkValue($MAL_NIL_TYPE)

  elseif (strcmp(fn.string, "time-ms") == 0) ithen
    if (args.length != 0) ithen
      result init MalArityError(fn.string, 0, args.length)
    else
      seconds:i date
      result init MalMkValue($MAL_NUMBER_TYPE)
      result.number = seconds * 1000
    endif

  elseif (strcmp(fn.string, "csound/eval") == 0 || strcmp(fn.string, "csound-eval") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      source:MalValue init MalAt(args, 0)

      if (source.type != $MAL_STRING_TYPE) ithen
        result init MalMkError(sprintf("%s: expected string argument", fn.string))
      else
        code:S init source.string
        result init MalCsoundEval(code)
      endif
    endif

  elseif (strcmp(fn.string, "csound/param-bindings") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalCsoundParamBindings(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "csound/compile-inst") == 0) ithen
    if (args.length != 3) ithen
      result init MalArityError(fn.string, 3, args.length)
    else
      instrumentName:MalValue init MalAt(args, 0)
      parameters:MalValue init MalAt(args, 1)
      graph:MalValue init MalAt(args, 2)
      result init MalCompileCsoundInstrument( \
        instrumentName, parameters, graph)
    endif

  elseif (strcmp(fn.string, "csound/at-rate") == 0 || \
          strcmp(fn.string, "csound/array") == 0 || \
          strcmp(fn.string, "csound/aget") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    elseif (strcmp(fn.string, "csound/at-rate") == 0) ithen
      result init MalCsoundAtRate(MalAt(args, 0), MalAt(args, 1))
    elseif (strcmp(fn.string, "csound/array") == 0) ithen
      result init MalCsoundArray(MalAt(args, 0), MalAt(args, 1))
    else
      result init MalCsoundArrayAt(MalAt(args, 0), MalAt(args, 1))
    endif

  elseif (strcmp(fn.string, "csound/outputs") == 0 || \
          strcmp(fn.string, "csound/type") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    elseif (strcmp(fn.string, "csound/type") == 0) ithen
      result init MalCsoundType(MalAt(args, 0))
    else
      result init MalCsoundOutputs(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "csound/source") == 0) ithen
    if (args.length != 3) ithen
      result init MalArityError(fn.string, 3, args.length)
    else
      result init MalCsoundInstrumentSource(MalAt(args, 0), MalAt(args, 1), MalAt(args, 2))
    endif

  elseif (strcmp(fn.string, "csound/do") == 0) ithen
    result init MalCsoundSequence(args)
  elseif (strcmp(fn.string, "csound/event") == 0) ithen
    result init MalCsoundEvent(args)

  elseif (strcmp(fn.string, "readline") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      prompt:MalValue init MalAt(args, 0)

      if (prompt.type != $MAL_STRING_TYPE) ithen
        result init MalMkError("readline: expected string argument")
      else
        // Terminal I/O belongs to the k-rate driver.
        result init MalInputTake()
      endif
    endif

  elseif (strcmp(fn.string, "read-string") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) ithen
        result init MalMkError("read-string: expected string argument")
      else
        result init read_str(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "slurp") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) ithen
        result init MalMkError("slurp: expected string argument")
      else
        result init MalSlurpFile(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "atom") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalMkAtom(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "atom?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      result init MalMkBool(value.type == $MAL_ATOM_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "deref") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      atom:MalValue init MalAt(args, 0)

      if (atom.type == $MAL_REDUCED_TYPE) ithen
        result init MalAt(atom, 0)
      elseif (atom.type != $MAL_ATOM_TYPE) ithen
        result init MalMkError("deref: expected atom or reduced value")
      else
        result init MalAtomValue(atom)
      endif
    endif

  elseif (strcmp(fn.string, "reset!") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      atom:MalValue init MalAt(args, 0)

      if (atom.type != $MAL_ATOM_TYPE) ithen
        result init MalMkError("reset!: first argument must be an atom")
      else
        value:MalValue init MalAt(args, 1)
        result init MalAtomSetValue(atom, value)
      endif
    endif

  elseif (strcmp(fn.string, "swap!") == 0) ithen
    if (args.length < 2) ithen
      result init MalMkError(sprintf("swap!: expected at least 2 arguments, got %d", \
        args.length))
    else
      atom:MalValue init MalAt(args, 0)

      if (atom.type != $MAL_ATOM_TYPE) ithen
        result init MalMkError("swap!: first argument must be an atom")
      else
        applyFn:MalValue init MalAt(args, 1)
        applyArgs:MalValue init MalMkValue($MAL_LIST_TYPE)
        applyArgs init MalAppendValue(applyArgs, MalAtomValue(atom))

        if (args.length > 2) ithen
          for index in [2 ... args.length - 1] do
            applyArgs init MalAppendValue(applyArgs, MalAt(args, index))
          od
        endif

        result init MalApply(applyFn, applyArgs)
        if (result.type != $MAL_ERROR_TYPE) ithen
          result init MalAtomSetValue(atom, result)
        endif
      endif
    endif

  elseif (strcmp(fn.string, "=") == 0) ithen
    if (args.length != 2) ithen
      result init MalArityError(fn.string, 2, args.length)
    else
      left:MalValue init MalAt(args, 0)
      right:MalValue init MalAt(args, 1)
      result init MalMkBool(MalEquals(left, right))
    endif

  elseif (strcmp(fn.string, ">") == 0 || \
          strcmp(fn.string, ">=") == 0 || \
          strcmp(fn.string, "<") == 0 || \
          strcmp(fn.string, "<=") == 0) ithen
    result init MalApplyNumericComparison(fn, args)

  elseif (strcmp(fn.string, "not") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      value:MalValue init MalAt(args, 0)
      result init MalMkBool(MalIsTruthy(value) == 0 ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "macro?") == 0) ithen
    if (args.length != 1) ithen
      result init MalArityError(fn.string, 1, args.length)
    else
      result init MalMkBool(MalIsMacro(MalAt(args, 0)))
    endif

  elseif (strcmp(fn.string, "prn") == 0) ithen
    output:S init MalJoinPrintedArgs(args, 1, " ")
    prints "%s\n", output
    result init MalMkValue($MAL_NIL_TYPE)

  else
    result init MalApplyCoreBuiltin(fn, args)
  endif

  xout result
endop

opcode MalRestParamIndex(params:MalValue):i
  result:i = -1

  if (params.length > 0) ithen
    for index in [0 ... params.length - 1] do
      param:MalValue init MalAt(params, index)

      if (param.type == $MAL_SYMBOL_TYPE && strcmp(param.string, "&") == 0) ithen
        result = index
        break
      endif
    od
  endif

  xout result
endop

opcode MalBindFunctionEnv(fn:MalValue, args:MalValue):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  callEnv:MalEnv init MalEnvHandle(-1)
  params:MalValue init MalFunctionParams(fn)
  restIndex:i = MalRestParamIndex(params)
  requiredCount:i = restIndex >= 0 ? restIndex : params.length

  if (restIndex < 0 && args.length != params.length) ithen
    result init MalMkError(sprintf("fn*: expected %d arguments, got %d", \
      params.length, args.length))
  elseif (restIndex >= 0 && args.length < requiredCount) ithen
    result init MalMkError(sprintf("fn*: expected at least %d arguments, got %d", \
      requiredCount, args.length))
  elseif (lenarray(fn.env) == 0) ithen
    result init MalMkError("fn*: missing closure environment")
  else
    closure:MalEnv[] init fn.env
    capturedEnv:MalEnv init MalEnvResolve(closure[0])
    callEnv init MalMkEnvWithOuter(capturedEnv)

    if (requiredCount > 0) ithen
      for index in [0 ... requiredCount - 1] do
        param:MalValue init MalAt(params, index)
        arg:MalValue init MalAt(args, index)
        callEnv init MalEnvSet(callEnv, param.string, arg)
      od
    endif

    if (restIndex >= 0) ithen
      restName:MalValue init MalAt(params, restIndex + 1)
      restValues:MalValue init MalMkValue($MAL_LIST_TYPE)

      if (args.length > requiredCount) ithen
        for index in [requiredCount ... args.length - 1] do
          arg:MalValue init MalAt(args, index)
          restValues init MalAppendValue(restValues, arg)
        od
      endif

      callEnv init MalEnvSet(callEnv, restName.string, restValues)
    endif

  endif

  xout result, callEnv
endop

opcode MalApplyFunction(fn:MalValue, args:MalValue):MalValue
  result:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)

  if (result.type != $MAL_ERROR_TYPE) ithen
    body:MalValue init MalFunctionBody(fn)
    bodyInputEnv:MalEnv init callEnv
    result, callEnv = EVAL_ENV(body, bodyInputEnv)
  endif

  MalEnvRelease(callEnv)

  xout result
endop

opcode MalApply(fn:MalValue, args:MalValue):MalValue
  if (fn.type == $MAL_BUILTIN_OPERATOR_TYPE) ithen
    result:MalValue init MalApplyBuiltinOperator(fn, args)
  elseif (fn.type == $MAL_BUILTIN_TYPE) ithen
    result:MalValue init MalApplyBuiltin(fn, args)
  elseif (fn.type == $MAL_BUILTIN_OPCODE_TYPE) ithen
    result:MalValue init MalApplyCsoundOpcode(fn, args)
  elseif (fn.type == $MAL_FUNCTION_TYPE) ithen
    result:MalValue init MalApplyFunction(fn, args)
  elseif (fn.type == $MAL_CSOUND_INSTRUMENT_TYPE) ithen
    result:MalValue init MalScheduleCsoundInstrument(fn, args, 0, 1)
  else
    result:MalValue init MalMkError(sprintf("cannot apply %s", pr_str(fn)))
  endif

  xout result
endop

opcode MalEvalSequenceEnv(ast:MalValue, env:MalEnv, startIndex:i, resultType:i):(MalValue, MalEnv)
  result:MalValue init MalMkValue(resultType)
  currentEnv:MalEnv init env
  index:i = startIndex
  done:i = 0

  while (index < ast.length && done == 0) do
    value:MalValue init MalAt(ast, index)
    valueInputEnv:MalEnv init currentEnv
    evaluated:MalValue, currentEnv = EVAL_ENV(value, valueInputEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) ithen
      result init evaluated
      done = 1
    else
      result init MalAppendValue(result, evaluated)
    endif

    index += 1
  od

  xout result, currentEnv
endop

opcode MalUnevaluatedArgs(ast:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_LIST_TYPE)

  if (ast.length > 1) ithen
    for index in [1 ... ast.length - 1] do
      result init MalAppendValue(result, MalAt(ast, index))
    od
  endif

  xout result
endop

opcode MalEvalHashMapEnv(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_HASH_MAP_TYPE)
  currentEnv:MalEnv init env
  index:i = 0
  done:i = 0

  while (index < ast.length && done == 0) do
    key:MalValue init MalAt(ast, index)
    value:MalValue init MalAt(ast, index + 1)
    valueInputEnv:MalEnv init currentEnv
    evaluated:MalValue, currentEnv = EVAL_ENV(value, valueInputEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) ithen
      result init evaluated
      done = 1
    else
      result init MalMapAssoc(result, key, evaluated)
    endif

    index += 2
  od

  xout result, currentEnv
endop

opcode MalEvalAstEnv(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init ast
  currentEnv:MalEnv init env
  switch ast.type
    case $MAL_SYMBOL_TYPE
      result init MalEnvGet(env, ast.string)

    case $MAL_LIST_TYPE
      result, currentEnv = MalEvalSequenceEnv(ast, env, 0, $MAL_LIST_TYPE)

    case $MAL_VECTOR_TYPE
      result, currentEnv = MalEvalSequenceEnv(ast, env, 0, $MAL_VECTOR_TYPE)

    case $MAL_HASH_MAP_TYPE
      result, currentEnv = MalEvalHashMapEnv(ast, env)
  endsw

  xout result, currentEnv
endop

opcode MalEvalQuote(ast:MalValue):MalValue
  if (ast.length != 2) ithen
    result:MalValue init MalArityError("quote", 1, ast.length - 1)
  else
    result:MalValue init MalAt(ast, 1)
  endif

  xout result
endop

opcode MalQuasiquoteSequence(ast:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_LIST_TYPE)

  if (ast.length > 0) ithen
    for offset in [0 ... ast.length - 1] do
      index:i = ast.length - offset - 1
      element:MalValue init MalAt(ast, index)

      if (MalIsForm(element, "splice-unquote") == 1) ithen
        if (element.length != 2) ithen
          result init MalArityError("splice-unquote", 1, element.length - 1)
          break
        endif

        result init MalMkList3(MalMkSymbol("concat"), MalAt(element, 1), result)
      else
        quotedElement:MalValue init MalQuasiquote(element)

        if (quotedElement.type == $MAL_ERROR_TYPE) ithen
          result init quotedElement
          break
        endif

        result init MalMkList3(MalMkSymbol("cons"), quotedElement, result)
      endif
    od
  endif

  xout result
endop

opcode MalQuasiquote(ast:MalValue):MalValue
  result:MalValue init ast
  if (MalIsForm(ast, "unquote") == 1) ithen
    if (ast.length != 2) ithen
      result init MalArityError("unquote", 1, ast.length - 1)
    else
      result init MalAt(ast, 1)
    endif
  else
    switch ast.type
      case $MAL_LIST_TYPE
        result init MalQuasiquoteSequence(ast)

      case $MAL_VECTOR_TYPE
        quotedValues:MalValue init MalQuasiquoteSequence(ast)

        if (quotedValues.type == $MAL_ERROR_TYPE) ithen
          result init quotedValues
        else
          result init MalMkList2(MalMkSymbol("vec"), quotedValues)
        endif

      case $MAL_SYMBOL_TYPE
        result init MalMkList2(MalMkSymbol("quote"), ast)

      case $MAL_HASH_MAP_TYPE
        result init MalMkList2(MalMkSymbol("quote"), ast)
    endsw
  endif

  xout result
endop

opcode MalIsFnForm(value:MalValue):i
  result:i = 0

  if (value.type == $MAL_LIST_TYPE && value.length > 0) ithen
    head:MalValue init MalAt(value, 0)

    if (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) ithen
      result = 1
    endif
  endif

  xout result
endop

opcode MalFunctionCaptureEnv(fn:MalValue, env:MalEnv):MalValue
  if (fn.type == $MAL_FUNCTION_TYPE) ithen
    retainedEnv:MalEnv init MalEnvRetain(env)
    closure:MalEnv[] init 1
    closure[0] init MalEnvHandle(retainedEnv.id)
    result:MalValue init fn.type, fn.number, fn.string, fn.list, closure, \
      fn.metadata, fn.length, fn.isMacro, fn.astRef
  else
    result:MalValue init fn
  endif

  xout result
endop

opcode MalRefreshTopLevelFunctionClosures(env:MalEnv):MalEnv
  xout env
endop

opcode MalEvalDefinition(ast:MalValue, env:MalEnv, name:S, asMacro:i):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv init env
  if (ast.length != 3) ithen
    result init MalMkError(sprintf("%s: expected 2 arguments, got %d", \
      name, ast.length - 1))
  else
    symbol:MalValue init MalAt(ast, 1)
    valueForm:MalValue init MalAt(ast, 2)

    if (symbol.type != $MAL_SYMBOL_TYPE) ithen
      result init MalMkError(sprintf("%s: first argument must be a symbol", name))
    else
      definitionInputEnv:MalEnv init currentEnv
      value:MalValue, currentEnv = EVAL_ENV(valueForm, definitionInputEnv)

      if (value.type == $MAL_ERROR_TYPE) ithen
        result init value
      elseif (asMacro == 1 && value.type != $MAL_FUNCTION_TYPE) ithen
        result init MalMkError(sprintf("%s: value must be a function", name))
      else
        if (asMacro == 1) ithen
          value init MalFunctionAsMacro(value)
        endif

        currentEnv init MalEnvSet(currentEnv, symbol.string, value)

        if (MalIsFnForm(valueForm) == 1) ithen
          value init MalFunctionCaptureEnv(value, currentEnv)
          currentEnv init MalEnvSet(currentEnv, symbol.string, value)
        endif

        currentEnv init MalRefreshTopLevelFunctionClosures(currentEnv)
        value init MalEnvGet(currentEnv, symbol.string)
        result init value
      endif
    endif
  endif

  xout result, currentEnv
endop

opcode MalEvalDef(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue, currentEnv:MalEnv = \
    MalEvalDefinition(ast, env, "def!", 0)
  xout result, currentEnv
endop

opcode MalEvalDefMacro(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue, currentEnv:MalEnv = \
    MalEvalDefinition(ast, env, "defmacro!", 1)
  xout result, currentEnv
endop

opcode MalParamsAreValid(params:MalValue):i
  valid:i = 1
  restIndex:i = -1

  if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) ithen
    valid = 0
  elseif (params.length > 0) ithen
    for index in [0 ... params.length - 1] do
      param:MalValue init MalAt(params, index)

      if (param.type != $MAL_SYMBOL_TYPE) ithen
        valid = 0
        break
      elseif (strcmp(param.string, "&") == 0) ithen
        if (restIndex >= 0 || index != params.length - 2) ithen
          valid = 0
          break
        endif

        restIndex = index
      endif
    od
  endif

  xout valid
endop

opcode MalEvalFn(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv init env
  if (ast.length != 3) ithen
    result init MalMkError(sprintf("fn*: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    params:MalValue init MalAt(ast, 1)
    body:MalValue init MalAt(ast, 2)

    if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) ithen
      result init MalMkError("fn*: params must be list or vector")
    elseif (MalParamsAreValid(params) == 0) ithen
      result init MalMkError("fn*: params must be symbols")
    else
      result init MalMkFunction(params, body)
      result init MalFunctionCaptureEnv(result, currentEnv)
    endif
  endif

  xout result, currentEnv
endop

opcode MalEvalIf(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv init env
  if (ast.length < 3 || ast.length > 4) ithen
    result init MalMkError(sprintf("if: expected 2 or 3 arguments, got %d", \
      ast.length - 1))
  else
    conditionForm:MalValue init MalAt(ast, 1)
    branchInputEnv:MalEnv init currentEnv
    condition:MalValue, currentEnv = EVAL_ENV(conditionForm, branchInputEnv)

    if (condition.type == $MAL_ERROR_TYPE) ithen
      result init condition
    elseif (MalIsTruthy(condition) == 1) ithen
      thenForm:MalValue init MalAt(ast, 2)
      branchInputEnv init currentEnv
      result, currentEnv = EVAL_ENV(thenForm, branchInputEnv)
    elseif (ast.length == 4) ithen
      elseForm:MalValue init MalAt(ast, 3)
      branchInputEnv init currentEnv
      result, currentEnv = EVAL_ENV(elseForm, branchInputEnv)
    endif
  endif

  xout result, currentEnv
endop

opcode MalEvalDo(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv init env
  index:i = 1
  done:i = 0

  while (index < ast.length && done == 0) do
    form:MalValue init MalAt(ast, index)
    formInputEnv:MalEnv init currentEnv
    result, currentEnv = EVAL_ENV(form, formInputEnv)

    if (result.type == $MAL_ERROR_TYPE) ithen
      done = 1
    endif

    index += 1
  od

  xout result, currentEnv
endop

opcode MalEvalLet(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv init env
  letEnv:MalEnv init MalMkEnvWithOuter(env)

  if (ast.length != 3) ithen
    result init MalMkError(sprintf("let*: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    bindings:MalValue init MalAt(ast, 1)
    body:MalValue init MalAt(ast, 2)

    if (bindings.type != $MAL_LIST_TYPE && \
        bindings.type != $MAL_VECTOR_TYPE) ithen
      result init MalMkError("let*: bindings must be list or vector")
    elseif (bindings.length % 2 != 0) ithen
      result init MalMkError("let*: bindings must contain even number of forms")
    else
      index:i = 0
      done:i = 0

      while (index < bindings.length && done == 0) do
        name:MalValue init MalAt(bindings, index)
        valueForm:MalValue init MalAt(bindings, index + 1)

        if (name.type != $MAL_SYMBOL_TYPE) ithen
          result init MalMkError("let*: binding name must be a symbol")
          done = 1
        else
          letInputEnv:MalEnv init letEnv
          value:MalValue, letEnv = EVAL_ENV(valueForm, letInputEnv)

          if (value.type == $MAL_ERROR_TYPE) ithen
            result init value
            done = 1
          else
            letEnv init MalEnvSet(letEnv, name.string, value)

            index += 2
          endif
        endif
      od

      if (done == 0) ithen
        letInputEnv init letEnv
        result, letEnv = EVAL_ENV(body, letInputEnv)
      endif
    endif
  endif

  MalEnvRelease(letEnv)

  xout result, currentEnv
endop

opcode EVAL_ENV(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue init ast
  workAst:MalValue init ast
  evalEnv:MalEnv init env
  returnEnv:MalEnv init env
  recursiveInputEnv:MalEnv init env
  transientEnvIds:i[] init 0
  transientEnvCount:i = 0
  done:i = 0

  while (done == 0) do
    transientEnvId:i = -1
    hasDebug:i = MalEnvHas(evalEnv, "DEBUG-EVAL")

    if (hasDebug == 1) ithen
      debugValue:MalValue init MalEnvGet(evalEnv, "DEBUG-EVAL")

      if (MalIsTruthy(debugValue) == 1) ithen
        SdebugAst:S init pr_str(workAst)
        prints "EVAL: %s\n", SdebugAst
      endif
    endif

    if (workAst.type == $MAL_LIST_TYPE && workAst.length > 0) ithen
      head:MalValue init MalAt(workAst, 0)

      if (MalIsSymbolNamed(head, "quote") == 1) ithen
        result init MalEvalQuote(workAst)
        done = 1

      elseif (MalIsSymbolNamed(head, "quasiquote") == 1) ithen
        if (workAst.length != 2) ithen
          result init MalArityError("quasiquote", 1, workAst.length - 1)
          done = 1
        else
          workAst init MalQuasiquote(MalAt(workAst, 1))

          if (workAst.type == $MAL_ERROR_TYPE) ithen
            result init workAst
            done = 1
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "def!") == 0) ithen
        recursiveInputEnv init evalEnv
        result, evalEnv = MalEvalDef(workAst, recursiveInputEnv)
        done = 1

      elseif (MalIsSymbolNamed(head, "defmacro!") == 1) ithen
        recursiveInputEnv init evalEnv
        result, evalEnv = MalEvalDefMacro(workAst, recursiveInputEnv)
        done = 1

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) ithen
        recursiveInputEnv init evalEnv
        result, evalEnv = MalEvalFn(workAst, recursiveInputEnv)
        done = 1

      elseif (MalIsSymbolNamed(head, "try*") == 1) ithen
        tryArgCount:i = workAst.length - 1

        if (tryArgCount < 1 || tryArgCount > 2) ithen
          result init MalMkError(sprintf( \
            "try*: expected 1 or 2 arguments, got %d", tryArgCount))
          done = 1
        elseif (tryArgCount == 1) ithen
          workAst init MalAt(workAst, 1)
        else
          catchClause:MalValue init MalAt(workAst, 2)

          if (MalIsForm(catchClause, "catch*") == 0 || \
              catchClause.length != 3) ithen
            result init MalMkError( \
              "try*: second argument must be (catch* symbol handler)")
            done = 1
          else
            catchBinding:MalValue init MalAt(catchClause, 1)

            if (catchBinding.type != $MAL_SYMBOL_TYPE) ithen
              result init MalMkError("catch*: binding must be a symbol")
              done = 1
            else
              tryForm:MalValue init MalAt(workAst, 1)
              recursiveInputEnv init evalEnv
              tryResult:MalValue, evalEnv = EVAL_ENV( \
                tryForm, recursiveInputEnv)

              if (tryResult.type == $MAL_ERROR_TYPE) ithen
                catchEnv:MalEnv init MalMkEnvWithOuter(evalEnv)
                transientEnvId = catchEnv.id
                catchValue:MalValue init MalErrorPayload(tryResult)
                catchEnv init MalEnvSet( \
                  catchEnv, catchBinding.string, catchValue)
                workAst init MalAt(catchClause, 2)
                evalEnv init catchEnv
              else
                result init tryResult
                done = 1
              endif
            endif
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "if") == 0) ithen
        if (workAst.length < 3 || workAst.length > 4) ithen
          result init MalMkError(sprintf("if: expected 2 or 3 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          ifConditionForm:MalValue init MalAt(workAst, 1)
          recursiveInputEnv init evalEnv
          ifCondition:MalValue, evalEnv = EVAL_ENV( \
            ifConditionForm, recursiveInputEnv)

          if (ifCondition.type == $MAL_ERROR_TYPE) ithen
            result init ifCondition
            done = 1
          elseif (MalIsTruthy(ifCondition) == 1) ithen
            workAst init MalAt(workAst, 2)
          elseif (workAst.length == 4) ithen
            workAst init MalAt(workAst, 3)
          else
            result init MalMkValue($MAL_NIL_TYPE)
            done = 1
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "do") == 0) ithen
        if (workAst.length == 1) ithen
          result init MalMkValue($MAL_NIL_TYPE)
          done = 1
        else
          doIndex:i = 1
          doError:i = 0
          doLastIndex:i = workAst.length - 1

          while (doIndex < doLastIndex && doError == 0) do
            doForm:MalValue init MalAt(workAst, doIndex)
            recursiveInputEnv init evalEnv
            result, evalEnv = EVAL_ENV(doForm, recursiveInputEnv)

            if (result.type == $MAL_ERROR_TYPE) ithen
              doError = 1
              done = 1
            endif

            doIndex += 1
          od

          if (doError == 0) ithen
            workAst init MalAt(workAst, doLastIndex)
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "let*") == 0) ithen
        letEnv:MalEnv init MalMkEnvWithOuter(evalEnv)
        transientEnvId = letEnv.id

        if (workAst.length != 3) ithen
          result init MalMkError(sprintf("let*: expected 2 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          letBindings:MalValue init MalAt(workAst, 1)
          letBody:MalValue init MalAt(workAst, 2)

          if (letBindings.type != $MAL_LIST_TYPE && \
              letBindings.type != $MAL_VECTOR_TYPE) ithen
            result init MalMkError("let*: bindings must be list or vector")
            done = 1
          elseif (letBindings.length % 2 != 0) ithen
            result init MalMkError("let*: bindings must contain even number of forms")
            done = 1
          else
            letIndex:i = 0
            letError:i = 0

            while (letIndex < letBindings.length && letError == 0) do
              letName:MalValue init MalAt(letBindings, letIndex)
              letValueForm:MalValue init MalAt(letBindings, letIndex + 1)

              if (letName.type != $MAL_SYMBOL_TYPE) ithen
                result init MalMkError("let*: binding name must be a symbol")
                letError = 1
                done = 1
              else
                recursiveInputEnv init letEnv
                letValue:MalValue, letEnv = EVAL_ENV( \
                  letValueForm, recursiveInputEnv)

                if (letValue.type == $MAL_ERROR_TYPE) ithen
                  result init letValue
                  letError = 1
                  done = 1
                else
                  letEnv init MalEnvSet(letEnv, letName.string, letValue)

                  letIndex += 2
                endif
              endif
            od

            if (letError == 0) ithen
              workAst init letBody
              evalEnv init letEnv
            endif
          endif
        endif

      else
        recursiveInputEnv init evalEnv
        fn:MalValue, evalEnv = EVAL_ENV(head, recursiveInputEnv)

        if (fn.type == $MAL_ERROR_TYPE) ithen
          result init fn
          done = 1
        elseif (MalIsMacro(fn) == 1) ithen
          rawArgs:MalValue init MalUnevaluatedArgs(workAst)
          expansion:MalValue init MalApplyFunction(fn, rawArgs)

          if (expansion.type == $MAL_ERROR_TYPE) ithen
            result init expansion
            done = 1
          else
            workAst init expansion
          endif
        else
          recursiveInputEnv init evalEnv
          args:MalValue, evalEnv = MalEvalSequenceEnv( \
            workAst, recursiveInputEnv, 1, $MAL_LIST_TYPE)

          if (args.type == $MAL_ERROR_TYPE) ithen
            result init args
            done = 1
          elseif (fn.type == $MAL_BUILTIN_TYPE && strcmp(fn.string, "eval") == 0) ithen
            if (args.length != 1) ithen
              result init MalArityError(fn.string, 1, args.length)
              done = 1
            else
              evalAst:MalValue init MalAt(args, 0)
              evalRoot:MalEnv init MalEnvRoot(evalEnv)
              recursiveInputEnv init evalRoot
              result, evalRoot = EVAL_ENV(evalAst, recursiveInputEnv)
              evalEnv init MalEnvSetRoot(evalEnv, evalRoot)

              done = 1
            endif
          elseif (fn.type == $MAL_FUNCTION_TYPE) ithen
            bindStatus:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)

            if (bindStatus.type == $MAL_ERROR_TYPE) ithen
              result init bindStatus
              done = 1
            else
              transientEnvId = callEnv.id
              workAst init MalFunctionBody(fn)
              evalEnv init callEnv
            endif
          else
            result init MalApply(fn, args)
            done = 1
          endif
        endif
      endif
    else
      recursiveInputEnv init evalEnv
      result, evalEnv = MalEvalAstEnv(workAst, recursiveInputEnv)

      done = 1
    endif

    if (transientEnvId >= 0) ithen
      transientCapacity:i = lenarray(transientEnvIds)

      if (transientEnvCount >= transientCapacity) ithen
        preservedEnvIds:i[] init transientEnvCount

        if (transientEnvCount > 0) ithen
          for copyIndex in [0 ... transientEnvCount - 1] do
            preservedEnvIds[copyIndex] = transientEnvIds[copyIndex]
          od
        endif

        newTransientCapacity:i = transientCapacity == 0 ? 16 : transientCapacity * 2
        transientEnvIds init newTransientCapacity

        if (transientEnvCount > 0) ithen
          for copyIndex in [0 ... transientEnvCount - 1] do
            transientEnvIds[copyIndex] = preservedEnvIds[copyIndex]
          od
        endif
      endif

      transientEnvIds[transientEnvCount] = transientEnvId
      transientEnvCount += 1
    endif
  od

  returnEnv init MalEnvResolve(returnEnv)

  if (transientEnvCount > 0) ithen
    for releaseIndex in [0 ... transientEnvCount - 1] do
      reverseIndex:i = transientEnvCount - releaseIndex - 1
      envId:i = transientEnvIds[reverseIndex]
      MalEnvRelease(MalEnvHandle(envId))
    od
  endif

  xout result, returnEnv
endop

opcode EVAL(ast:MalValue, env:MalEnv):MalValue
  result:MalValue, updatedEnv:MalEnv = EVAL_ENV(ast, env)
  xout result
endop

opcode MalEvalSourceEnv(source:S, env:MalEnv):(MalValue, MalEnv)
  ast:MalValue init read_str(source)
  currentEnv:MalEnv init env
  if (ast.type == $MAL_ERROR_TYPE) ithen
    result:MalValue init ast
  else
    sourceInputEnv:MalEnv init currentEnv
    result, currentEnv = EVAL_ENV(ast, sourceInputEnv)
  endif

  xout result, currentEnv
endop

#include "src/threading.orc"

opcode MalMkStep6Env():MalEnv
  env:MalEnv init MalMkStep2Env()
  env init MalEnvSet(env, "*ARGV*", MalMkValue($MAL_LIST_TYPE))
  source:S init "(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \"\\nnil)\")))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "load-file bootstrap failed: %s\n", result.string
  endif

  xout env
endop

opcode MalMkStep8Env():MalEnv
  env:MalEnv init MalMkStep6Env()
  source:S init "(defmacro! cond (fn* (& xs) (if (> (count xs) 0) "
  source strcat source, "(list 'if (first xs) "
  source strcat source, "(if (> (count xs) 1) (nth xs 1) "
  source strcat source, "(throw \"odd number of forms to cond\")) "
  source strcat source, "(cons 'cond (rest (rest xs)))))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "cond bootstrap failed: %s\n", result.string
  endif

  xout env
endop

opcode MalMkStep9Env():MalEnv
  env:MalEnv init MalMkStep8Env()
  env init MalEnvSet(env, "throw", MalMkBuiltin("throw"))
  env init MalEnvSet(env, "apply", MalMkBuiltin("apply"))
  env init MalEnvSet(env, "map", MalMkBuiltin("map"))
  env init MalEnvSet(env, "nil?", MalMkBuiltin("nil?"))
  env init MalEnvSet(env, "true?", MalMkBuiltin("true?"))
  env init MalEnvSet(env, "false?", MalMkBuiltin("false?"))
  env init MalEnvSet(env, "symbol", MalMkBuiltin("symbol"))
  env init MalEnvSet(env, "symbol?", MalMkBuiltin("symbol?"))
  env init MalEnvSet(env, "keyword", MalMkBuiltin("keyword"))
  env init MalEnvSet(env, "keyword?", MalMkBuiltin("keyword?"))
  env init MalEnvSet(env, "vector", MalMkBuiltin("vector"))
  env init MalEnvSet(env, "vector?", MalMkBuiltin("vector?"))
  env init MalEnvSet(env, "sequential?", MalMkBuiltin("sequential?"))
  env init MalEnvSet(env, "hash-map", MalMkBuiltin("hash-map"))
  env init MalEnvSet(env, "map?", MalMkBuiltin("map?"))
  env init MalEnvSet(env, "assoc", MalMkBuiltin("assoc"))
  env init MalEnvSet(env, "dissoc", MalMkBuiltin("dissoc"))
  env init MalEnvSet(env, "get", MalMkBuiltin("get"))
  env init MalEnvSet(env, "contains?", MalMkBuiltin("contains?"))
  env init MalEnvSet(env, "keys", MalMkBuiltin("keys"))
  env init MalEnvSet(env, "vals", MalMkBuiltin("vals"))
  env init MalEnvSet(env, "pr-str", MalMkBuiltin("pr-str"))
  env init MalRefreshTopLevelFunctionClosures(env)
  xout env
endop

opcode MalMkStepAEnv():MalEnv
  env:MalEnv init MalMkStep9Env()
  env init MalEnvSet(env, "gensym", MalMkBuiltin("gensym"))
  env init MalEnvSet(env, "meta", MalMkBuiltin("meta"))
  env init MalEnvSet(env, "with-meta", MalMkBuiltin("with-meta"))
  env init MalEnvSet(env, "string?", MalMkBuiltin("string?"))
  env init MalEnvSet(env, "number?", MalMkBuiltin("number?"))
  env init MalEnvSet(env, "fn?", MalMkBuiltin("fn?"))
  env init MalEnvSet(env, "seq", MalMkBuiltin("seq"))
  env init MalEnvSet(env, "conj", MalMkBuiltin("conj"))
  env init MalEnvSet(env, "time-ms", MalMkBuiltin("time-ms"))
  env init MalEnvSet(env, "println", MalMkBuiltin("println"))
  env init MalEnvSet(env, "readline", MalMkBuiltin("readline"))
  source:S init "(def! *host-language* \"Csound7\")"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "host language bootstrap failed: %s\n", result.string
  endif

  env init MalInstallCoreHelpers(env)
  env init MalInstallThreadingMacros(env)
  xout env
endop

opcode MalMkCsoundEnv():MalEnv
  env:MalEnv init MalMkStepAEnv()
  env init MalEnvSet(env, "csound-eval", MalMkBuiltin("csound-eval"))
  env init MalEnvSet(env, "csound/param-bindings", \
    MalMkBuiltin("csound/param-bindings"))
  env init MalEnvSet(env, "csound/compile-inst", \
    MalMkBuiltin("csound/compile-inst"))
  env init MalEnvSet(env, "csound/event", MalMkBuiltin("csound/event"))
  env init MalEnvSet(env, "csound/do", MalMkBuiltin("csound/do"))
  env init MalEnvSet(env, "csound/eval", MalMkBuiltin("csound/eval"))
  env init MalEnvSet(env, "csound/at-rate", MalMkBuiltin("csound/at-rate"))
  env init MalEnvSet(env, "csound/array", MalMkBuiltin("csound/array"))
  env init MalEnvSet(env, "csound/aget", MalMkBuiltin("csound/aget"))
  env init MalEnvSet(env, "csound/outputs", MalMkBuiltin("csound/outputs"))
  env init MalEnvSet(env, "csound/type", MalMkBuiltin("csound/type"))
  env init MalEnvSet(env, "csound/source", MalMkBuiltin("csound/source"))
  env init MalCsoundInstallOpcodes(env)

  source:S init "(defmacro! csound/definst (fn* (name params body) (list 'def! name (list 'csound/compile-inst (list 'quote name) (list 'quote params) (list 'let* (csound/param-bindings params) body)))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) ithen
    prints "definst bootstrap failed: %s\n", result.string
  endif

  ;; Compatibility alias; new programs use the qualified macro.
  env init MalEnvSet(env, "definst", MalEnvGet(env, "csound/definst"))

  xout env
endop
