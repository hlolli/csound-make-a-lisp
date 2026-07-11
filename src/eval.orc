declare EVAL_ENV(result:MalValue, nextEnv:MalEnv):(MalValue, MalEnv)
declare MalEquals(left:MalValue, right:MalValue):(i)
declare MalApply(fn:MalValue, args:MalValue):(MalValue)
declare MalQuasiquote(ast:MalValue):(MalValue)

opcode MalApplyBuiltinOperator(fn:MalValue, args:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_NUMBER_TYPE)

  if (args.length != 2) then
    result = MalMkError(sprintf("%s: expected 2 arguments, got %d", \
      fn.string, args.length))
  else
    leftArg:MalValue = MalAt(args, 0)
    rightArg:MalValue = MalAt(args, 1)

    if (MalIsCsoundNode(leftArg) == 1 || MalIsCsoundNode(rightArg) == 1) then
      leftIsGraphValue:i = leftArg.type == $MAL_NUMBER_TYPE || \
        MalIsCsoundNode(leftArg) == 1
      rightIsGraphValue:i = rightArg.type == $MAL_NUMBER_TYPE || \
        MalIsCsoundNode(rightArg) == 1

      if (leftIsGraphValue == 0 || rightIsGraphValue == 0) then
        result = MalMkError(sprintf( \
          "%s: expected numeric or Csound graph arguments", fn.string))
      else
        result = MalMkCsoundInfix(fn.string, args)
      endif
    elseif (leftArg.type != $MAL_NUMBER_TYPE || \
            rightArg.type != $MAL_NUMBER_TYPE) then
      result = MalMkError(sprintf("%s: expected numeric arguments", fn.string))
    else
      left:i = leftArg.number
      right:i = rightArg.number

      if (strlen(fn.string) != 1) then
        result = MalMkError(sprintf("unknown builtin operator '%s'", fn.string))
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
            if (right == 0) then
              result = MalMkError("/: division by zero")
            else
              result.number = int(left / right)
            endif

          default
            result = MalMkError(sprintf("unknown builtin operator '%s'", fn.string))
        endsw
      endif
    endif
  endif

  xout result
endop

opcode MalMkBool(condition:i):MalValue
  if (condition == 0) then
    result:MalValue = MalMkValue($MAL_FALSE_TYPE)
  else
    result:MalValue = MalMkValue($MAL_TRUE_TYPE)
  endif

  xout result
endop

opcode MalIsTruthy(value:MalValue):i
  result:i = 1

  if (value.type == $MAL_NIL_TYPE || value.type == $MAL_FALSE_TYPE) then
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

  if (ast.type == $MAL_LIST_TYPE && ast.length > 0) then
    head:MalValue = MalAt(ast, 0)
    result = MalIsSymbolNamed(head, name)
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

  if (value.length > 0) then
    for index in [0 ... value.length - 1] do
      values[index] = MalAt(value, index)
    od
  endif

  result:MalValue = MalMkValue(resultType)
  result.list = values
  result.length = value.length
  xout result
endop

opcode MalFlattenApplyArgs(args:MalValue):MalValue
  finalSequence:MalValue = MalAt(args, args.length - 1)
  prefixLength:i = args.length - 2
  flattenedLength:i = prefixLength + finalSequence.length
  values:MalValue[] init flattenedLength

  if (prefixLength > 0) then
    for index in [0 ... prefixLength - 1] do
      values[index] = MalAt(args, index + 1)
    od
  endif

  if (finalSequence.length > 0) then
    for index in [0 ... finalSequence.length - 1] do
      values[prefixLength + index] = MalAt(finalSequence, index)
    od
  endif

  result:MalValue = MalMkValue($MAL_LIST_TYPE)
  result.list = values
  result.length = flattenedLength
  xout result
endop

opcode MalMapSequence(fn:MalValue, sequence:MalValue):MalValue
  values:MalValue[] init sequence.length
  result:MalValue = MalMkValue($MAL_LIST_TYPE)
  failed:i = 0

  if (sequence.length > 0) then
    for index in [0 ... sequence.length - 1] do
      callArgs:MalValue = MalMkList1(MalAt(sequence, index))
      mapped:MalValue = MalApply(fn, callArgs)

      if (mapped.type == $MAL_ERROR_TYPE) then
        result = mapped
        failed = 1
        break
      endif

      values[index] = mapped
    od
  endif

  if (failed == 0) then
    result.list = values
    result.length = sequence.length
  endif

  xout result
endop

opcode MalAssocPairs(mapValue:MalValue, args:MalValue, startIndex:i):MalValue
  result:MalValue = mapValue
  pairCount:i = int((args.length - startIndex) / 2)

  if (pairCount > 0) then
    for pairIndex in [0 ... pairCount - 1] do
      keyIndex:i = startIndex + pairIndex * 2
      result = MalMapAssoc( \
        result, MalAt(args, keyIndex), MalAt(args, keyIndex + 1))
    od
  endif

  xout result
endop

opcode MalDissocKeys(mapValue:MalValue, args:MalValue):MalValue
  result:MalValue = mapValue

  if (args.length > 1) then
    for index in [1 ... args.length - 1] do
      result = MalMapDissoc(result, MalAt(args, index))
    od
  endif

  xout result
endop

opcode MalJoinPrintedArgs(args:MalValue, printReadably:i, separator:S):S
  output:S = ""

  if (args.length > 0) then
    for index in [0 ... args.length - 1] do
      if (index > 0) then
        output strcat output, separator
      endif

      output strcat output, \
        pr_str_with_readability(MalAt(args, index), printReadably)
    od
  endif

  xout output
endop

opcode MalArityError(name:S, expected:i, actual:i):MalValue
  result:MalValue = MalMkError(sprintf("%s: expected %d arguments, got %d", \
    name, expected, actual))
  xout result
endop

opcode MalApplyTypePredicate(fn:MalValue, args:MalValue, expectedType:i):MalValue
  if (args.length != 1) then
    result:MalValue = MalArityError(fn.string, 1, args.length)
  else
    value:MalValue = MalAt(args, 0)
    matches:i = value.type == expectedType
    result:MalValue = MalMkBool(matches)
  endif

  xout result
endop

opcode MalNumberComparison(name:S, left:i, right:i):i
  result:i = 0

  if (strcmp(name, ">") == 0) then
    result = left > right
  elseif (strcmp(name, ">=") == 0) then
    result = left >= right
  elseif (strcmp(name, "<") == 0) then
    result = left < right
  elseif (strcmp(name, "<=") == 0) then
    result = left <= right
  endif

  xout result
endop

opcode MalApplyNumericComparison(fn:MalValue, args:MalValue):MalValue
  if (args.length != 2) then
    result:MalValue = MalArityError(fn.string, 2, args.length)
  else
    leftArg:MalValue = MalAt(args, 0)
    rightArg:MalValue = MalAt(args, 1)

    if (leftArg.type != $MAL_NUMBER_TYPE || \
        rightArg.type != $MAL_NUMBER_TYPE) then
      result:MalValue = MalMkError(sprintf("%s: expected numeric arguments", \
        fn.string))
    else
      comparison:i = MalNumberComparison(fn.string, leftArg.number, rightArg.number)
      result:MalValue = MalMkBool(comparison)
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
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  switch value.type
    case $MAL_NIL_TYPE
      result = value

    case $MAL_LIST_TYPE
      if (value.length > 0) then
        result = value
      endif

    case $MAL_VECTOR_TYPE
      if (value.length > 0) then
        result = MalCopySequenceAs(value, $MAL_LIST_TYPE)
      endif

    case $MAL_STRING_TYPE
      characterCount:i = strlen(value.string)

      if (characterCount > 0) then
        characters:MalValue[] init characterCount

        for index in [0 ... characterCount - 1] do
          character:S = strsub(value.string, index, index + 1)
          characters[index] = MalMkString(character)
        od

        result = MalMkValue($MAL_LIST_TYPE)
        result.list = characters
        result.length = characterCount
      endif

    default
      result = MalMkError("seq: expected list, vector, string, or nil")
  endsw

  xout result
endop

opcode MalConj(args:MalValue):MalValue
  collection:MalValue = MalAt(args, 0)
  addedCount:i = args.length - 1
  resultLength:i = collection.length + addedCount
  values:MalValue[] init resultLength
  result:MalValue = MalMkValue(collection.type)

  if (collection.type == $MAL_LIST_TYPE) then
    for index in [0 ... addedCount - 1] do
      values[index] = MalAt(args, args.length - index - 1)
    od

    if (collection.length > 0) then
      for index in [0 ... collection.length - 1] do
        values[addedCount + index] = MalAt(collection, index)
      od
    endif

  elseif (collection.type == $MAL_VECTOR_TYPE) then
    if (collection.length > 0) then
      for index in [0 ... collection.length - 1] do
        values[index] = MalAt(collection, index)
      od
    endif

    for index in [0 ... addedCount - 1] do
      values[collection.length + index] = MalAt(args, index + 1)
    od
  endif

  result.list = values
  result.length = resultLength
  xout result
endop

opcode MalSlurpFile(filename:S):MalValue
  result:MalValue = MalMkString("")
  content:S = ""
  line:S = ""
  lineNumber:i = 0

read_line:
  line, lineNumber readfi filename

  if (lineNumber != -1) then
    content strcat content, line
    igoto read_line
  endif

  result.string = content
  xout result
endop

opcode MalEquals(left:MalValue, right:MalValue):i
  result:i = 0
  leftIsSequence:i = 0
  rightIsSequence:i = 0

  if (left.type == $MAL_LIST_TYPE || left.type == $MAL_VECTOR_TYPE) then
    leftIsSequence = 1
  endif

  if (right.type == $MAL_LIST_TYPE || right.type == $MAL_VECTOR_TYPE) then
    rightIsSequence = 1
  endif

  if (leftIsSequence == 1 && rightIsSequence == 1) then
    if (left.length == right.length) then
      result = 1

      if (left.length > 0) then
        for index in [0 ... left.length - 1] do
          leftItem:MalValue = MalAt(left, index)
          rightItem:MalValue = MalAt(right, index)

          if (MalEquals(leftItem, rightItem) == 0) then
            result = 0
            break
          endif
        od
      endif
    endif
  elseif (left.type == $MAL_HASH_MAP_TYPE && \
          right.type == $MAL_HASH_MAP_TYPE) then
    if (left.length == right.length) then
      result = 1
      entryCount:i = int(left.length / 2)

      if (entryCount > 0) then
        for entryIndex in [0 ... entryCount - 1] do
          leftKeyIndex:i = entryIndex * 2
          rightKeyIndex:i = MalMapFindKey( \
            right, MalAt(left, leftKeyIndex))

          if (rightKeyIndex < 0) then
            result = 0
            break
          else
            leftValue:MalValue = MalAt(left, leftKeyIndex + 1)
            rightValue:MalValue = MalAt(right, rightKeyIndex + 1)

            if (MalEquals(leftValue, rightValue) == 0) then
              result = 0
              break
            endif
          endif
        od
      endif
    endif
  elseif (left.type == right.type) then
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
    endsw
  endif

  xout result
endop

opcode MalApplyBuiltin(fn:MalValue, args:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  if (strcmp(fn.string, "throw") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMkThrown(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "apply") == 0) then
    if (args.length < 2) then
      result = MalMkError(sprintf( \
        "apply: expected at least 2 arguments, got %d", args.length))
    else
      targetFn:MalValue = MalAt(args, 0)
      finalSequence:MalValue = MalAt(args, args.length - 1)

      if (MalIsSequential(finalSequence) == 0) then
        result = MalMkError( \
          "apply: final argument must be list or vector")
      else
        flattenedArgs:MalValue = MalFlattenApplyArgs(args)
        result = MalApply(targetFn, flattenedArgs)
      endif
    endif

  elseif (strcmp(fn.string, "map") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      targetFn:MalValue = MalAt(args, 0)
      sequence:MalValue = MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) then
        result = MalMkError("map: second argument must be list or vector")
      else
        result = MalMapSequence(targetFn, sequence)
      endif
    endif

  elseif (strcmp(fn.string, "nil?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_NIL_TYPE)

  elseif (strcmp(fn.string, "true?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_TRUE_TYPE)

  elseif (strcmp(fn.string, "false?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_FALSE_TYPE)

  elseif (strcmp(fn.string, "symbol?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_SYMBOL_TYPE)

  elseif (strcmp(fn.string, "string?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_STRING_TYPE)

  elseif (strcmp(fn.string, "number?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_NUMBER_TYPE)

  elseif (strcmp(fn.string, "fn?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMkBool(MalIsFn(MalAt(args, 0)))
    endif

  elseif (strcmp(fn.string, "symbol") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) then
        result = MalMkError("symbol: expected string argument")
      else
        result = MalMkSymbol(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "keyword") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)

      if (value.type == $MAL_KEYWORD_TYPE) then
        result = value
      elseif (value.type == $MAL_STRING_TYPE) then
        result = MalMkKeyword(value.string)
      else
        result = MalMkError("keyword: expected string or keyword argument")
      endif
    endif

  elseif (strcmp(fn.string, "keyword?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_KEYWORD_TYPE)

  elseif (strcmp(fn.string, "list") == 0) then
    result = args

  elseif (strcmp(fn.string, "vector") == 0) then
    result = MalCopySequenceAs(args, $MAL_VECTOR_TYPE)

  elseif (strcmp(fn.string, "vector?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_VECTOR_TYPE)

  elseif (strcmp(fn.string, "sequential?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      isSequential:i = MalIsSequential(value)
      result = MalMkBool(isSequential)
    endif

  elseif (strcmp(fn.string, "hash-map") == 0) then
    if (args.length % 2 != 0) then
      result = MalMkError("hash-map: expected even number of arguments")
    else
      emptyMap:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)
      result = MalAssocPairs(emptyMap, args, 0)
    endif

  elseif (strcmp(fn.string, "map?") == 0) then
    result = MalApplyTypePredicate(fn, args, $MAL_HASH_MAP_TYPE)

  elseif (strcmp(fn.string, "assoc") == 0) then
    if (args.length < 1) then
      result = MalMkError("assoc: expected at least 1 argument, got 0")
    else
      mapValue:MalValue = MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("assoc: first argument must be a hash map")
      elseif ((args.length - 1) % 2 != 0) then
        result = MalMkError("assoc: expected key/value pairs")
      else
        result = MalAssocPairs(mapValue, args, 1)
      endif
    endif

  elseif (strcmp(fn.string, "dissoc") == 0) then
    if (args.length < 1) then
      result = MalMkError("dissoc: expected at least 1 argument, got 0")
    else
      mapValue:MalValue = MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("dissoc: first argument must be a hash map")
      else
        result = MalDissocKeys(mapValue, args)
      endif
    endif

  elseif (strcmp(fn.string, "get") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      mapValue:MalValue = MalAt(args, 0)
      key:MalValue = MalAt(args, 1)

      if (mapValue.type == $MAL_NIL_TYPE) then
        result = MalMkValue($MAL_NIL_TYPE)
      elseif (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("get: first argument must be a hash map or nil")
      else
        result = MalMapGet(mapValue, key)
      endif
    endif

  elseif (strcmp(fn.string, "contains?") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      mapValue:MalValue = MalAt(args, 0)
      key:MalValue = MalAt(args, 1)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("contains?: first argument must be a hash map")
      else
        found:i = MalMapFindKey(mapValue, key) >= 0
        result = MalMkBool(found)
      endif
    endif

  elseif (strcmp(fn.string, "keys") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      mapValue:MalValue = MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("keys: expected hash map argument")
      else
        result = MalMapKeys(mapValue)
      endif
    endif

  elseif (strcmp(fn.string, "vals") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      mapValue:MalValue = MalAt(args, 0)

      if (mapValue.type != $MAL_HASH_MAP_TYPE) then
        result = MalMkError("vals: expected hash map argument")
      else
        result = MalMapValues(mapValue)
      endif
    endif

  elseif (strcmp(fn.string, "meta") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMeta(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "with-meta") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      result = MalWithMeta(MalAt(args, 0), MalAt(args, 1))
    endif

  elseif (strcmp(fn.string, "cons") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      first:MalValue = MalAt(args, 0)
      sequence:MalValue = MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) then
        result = MalMkError("cons: second argument must be list or vector")
      else
        resultLength:i = sequence.length + 1
        values:MalValue[] init resultLength
        values[0] = first

        if (sequence.length > 0) then
          for index in [0 ... sequence.length - 1] do
            values[index + 1] = MalAt(sequence, index)
          od
        endif

        result = MalMkValue($MAL_LIST_TYPE)
        result.list = values
        result.length = resultLength
      endif
    endif

  elseif (strcmp(fn.string, "concat") == 0) then
    totalLength:i = 0
    valid:i = 1

    if (args.length > 0) then
      for index in [0 ... args.length - 1] do
        sequence:MalValue = MalAt(args, index)

        if (MalIsSequential(sequence) == 0) then
          valid = 0
          break
        endif

        totalLength += sequence.length
      od
    endif

    if (valid == 0) then
      result = MalMkError("concat: expected list or vector arguments")
    else
      values:MalValue[] init totalLength
      destinationIndex:i = 0

      if (args.length > 0) then
        for sequenceIndex in [0 ... args.length - 1] do
          sequence:MalValue = MalAt(args, sequenceIndex)

          if (sequence.length > 0) then
            for valueIndex in [0 ... sequence.length - 1] do
              values[destinationIndex] = MalAt(sequence, valueIndex)
              destinationIndex += 1
            od
          endif
        od
      endif

      result = MalMkValue($MAL_LIST_TYPE)
      result.list = values
      result.length = totalLength
    endif

  elseif (strcmp(fn.string, "vec") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue = MalAt(args, 0)

      if (MalIsSequential(sequence) == 0) then
        result = MalMkError("vec: expected list or vector argument")
      else
        result = MalCopySequenceAs(sequence, $MAL_VECTOR_TYPE)
      endif
    endif

  elseif (strcmp(fn.string, "nth") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      sequence:MalValue = MalAt(args, 0)
      indexValue:MalValue = MalAt(args, 1)

      if (MalIsSequential(sequence) == 0) then
        result = MalMkError("nth: first argument must be list or vector")
      elseif (indexValue.type != $MAL_NUMBER_TYPE) then
        result = MalMkError("nth: index must be a number")
      elseif (indexValue.number != int(indexValue.number)) then
        result = MalMkError("nth: index must be an integer")
      elseif (indexValue.number < 0 || indexValue.number >= sequence.length) then
        result = MalMkError("nth: index out of range")
      else
        index:i = indexValue.number
        result = MalAt(sequence, index)
      endif
    endif

  elseif (strcmp(fn.string, "first") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue = MalAt(args, 0)

      if (sequence.type == $MAL_NIL_TYPE || \
          (MalIsSequential(sequence) == 1 && sequence.length == 0)) then
        result = MalMkValue($MAL_NIL_TYPE)
      elseif (MalIsSequential(sequence) == 0) then
        result = MalMkError("first: expected list, vector, or nil")
      else
        result = MalAt(sequence, 0)
      endif
    endif

  elseif (strcmp(fn.string, "rest") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue = MalAt(args, 0)

      if (sequence.type != $MAL_NIL_TYPE && MalIsSequential(sequence) == 0) then
        result = MalMkError("rest: expected list, vector, or nil")
      else
        result = MalMkValue($MAL_LIST_TYPE)

        if (sequence.type != $MAL_NIL_TYPE && sequence.length > 1) then
          restLength:i = sequence.length - 1
          values:MalValue[] init restLength

          for index in [0 ... restLength - 1] do
            values[index] = MalAt(sequence, index + 1)
          od

          result.list = values
          result.length = restLength
        endif
      endif
    endif

  elseif (strcmp(fn.string, "seq") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalSeq(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "conj") == 0) then
    if (args.length < 2) then
      result = MalMkError(sprintf( \
        "conj: expected at least 2 arguments, got %d", args.length))
    else
      collection:MalValue = MalAt(args, 0)

      if (MalIsSequential(collection) == 0) then
        result = MalMkError("conj: first argument must be list or vector")
      else
        result = MalConj(args)
      endif
    endif

  elseif (strcmp(fn.string, "list?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      result = MalMkBool(value.type == $MAL_LIST_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "empty?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      isEmpty:i = value.type == $MAL_NIL_TYPE || \
        value.type == $MAL_LIST_TYPE && value.length == 0 || \
        value.type == $MAL_VECTOR_TYPE && value.length == 0 || \
        value.type == $MAL_HASH_MAP_TYPE && value.length == 0
      result = MalMkBool(isEmpty)
    endif

  elseif (strcmp(fn.string, "count") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      result = MalMkValue($MAL_NUMBER_TYPE)

      if (value.type == $MAL_NIL_TYPE) then
        result.number = 0
      elseif (value.type == $MAL_LIST_TYPE || \
              value.type == $MAL_VECTOR_TYPE) then
        result.number = value.length
      elseif (value.type == $MAL_HASH_MAP_TYPE) then
        result.number = int(value.length / 2)
      else
        result = MalMkError("count: expected sequence or nil")
      endif
    endif

  elseif (strcmp(fn.string, "str") == 0) then
    result = MalMkString(MalJoinPrintedArgs(args, 0, ""))

  elseif (strcmp(fn.string, "pr-str") == 0) then
    result = MalMkString(MalJoinPrintedArgs(args, 1, " "))

  elseif (strcmp(fn.string, "println") == 0) then
    output:S = MalJoinPrintedArgs(args, 0, " ")
    prints "%s\n", output
    result = MalMkValue($MAL_NIL_TYPE)

  elseif (strcmp(fn.string, "time-ms") == 0) then
    if (args.length != 0) then
      result = MalArityError(fn.string, 0, args.length)
    else
      seconds:i date
      result = MalMkValue($MAL_NUMBER_TYPE)
      result.number = seconds * 1000
    endif

  elseif (strcmp(fn.string, "csound-eval") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      source:MalValue = MalAt(args, 0)

      if (source.type != $MAL_STRING_TYPE) then
        result = MalMkError("csound-eval: expected string argument")
      else
        code:S = source.string
        result = MalCsoundEval(code)
      endif
    endif

  elseif (strcmp(fn.string, "csound/param-bindings") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalCsoundParamBindings(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "csound/compile-inst") == 0) then
    if (args.length != 3) then
      result = MalArityError(fn.string, 3, args.length)
    else
      instrumentName:MalValue = MalAt(args, 0)
      parameters:MalValue = MalAt(args, 1)
      graph:MalValue = MalAt(args, 2)
      result = MalCompileCsoundInstrument( \
        instrumentName, parameters, graph)
    endif

  elseif (strcmp(fn.string, "csound/event") == 0) then
    result = MalCsoundEvent(args)

  elseif (strcmp(fn.string, "readline") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      prompt:MalValue = MalAt(args, 0)

      if (prompt.type != $MAL_STRING_TYPE) then
        result = MalMkError("readline: expected string argument")
      else
        // Terminal I/O belongs to the k-rate driver.
        result = MalInputTake()
      endif
    endif

  elseif (strcmp(fn.string, "read-string") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) then
        result = MalMkError("read-string: expected string argument")
      else
        result = read_str(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "slurp") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)

      if (value.type != $MAL_STRING_TYPE) then
        result = MalMkError("slurp: expected string argument")
      else
        result = MalSlurpFile(value.string)
      endif
    endif

  elseif (strcmp(fn.string, "atom") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMkAtom(MalAt(args, 0))
    endif

  elseif (strcmp(fn.string, "atom?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      result = MalMkBool(value.type == $MAL_ATOM_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "deref") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      atom:MalValue = MalAt(args, 0)

      if (atom.type != $MAL_ATOM_TYPE) then
        result = MalMkError("deref: expected atom argument")
      else
        result = MalAtomValue(atom)
      endif
    endif

  elseif (strcmp(fn.string, "reset!") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      atom:MalValue = MalAt(args, 0)

      if (atom.type != $MAL_ATOM_TYPE) then
        result = MalMkError("reset!: first argument must be an atom")
      else
        value:MalValue = MalAt(args, 1)
        result = MalAtomSetValue(atom, value)
      endif
    endif

  elseif (strcmp(fn.string, "swap!") == 0) then
    if (args.length < 2) then
      result = MalMkError(sprintf("swap!: expected at least 2 arguments, got %d", \
        args.length))
    else
      atom:MalValue = MalAt(args, 0)

      if (atom.type != $MAL_ATOM_TYPE) then
        result = MalMkError("swap!: first argument must be an atom")
      else
        applyFn:MalValue = MalAt(args, 1)
        applyArgs:MalValue = MalMkValue($MAL_LIST_TYPE)
        applyArgs = MalAppendValue(applyArgs, MalAtomValue(atom))

        if (args.length > 2) then
          for index in [2 ... args.length - 1] do
            applyArgs = MalAppendValue(applyArgs, MalAt(args, index))
          od
        endif

        result = MalApply(applyFn, applyArgs)
        if (result.type != $MAL_ERROR_TYPE) then
          result = MalAtomSetValue(atom, result)
        endif
      endif
    endif

  elseif (strcmp(fn.string, "=") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      left:MalValue = MalAt(args, 0)
      right:MalValue = MalAt(args, 1)
      result = MalMkBool(MalEquals(left, right))
    endif

  elseif (strcmp(fn.string, ">") == 0 || \
          strcmp(fn.string, ">=") == 0 || \
          strcmp(fn.string, "<") == 0 || \
          strcmp(fn.string, "<=") == 0) then
    result = MalApplyNumericComparison(fn, args)

  elseif (strcmp(fn.string, "not") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = MalAt(args, 0)
      result = MalMkBool(MalIsTruthy(value) == 0 ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "macro?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMkBool(MalIsMacro(MalAt(args, 0)))
    endif

  elseif (strcmp(fn.string, "prn") == 0) then
    output:S = MalJoinPrintedArgs(args, 1, " ")
    prints "%s\n", output
    result = MalMkValue($MAL_NIL_TYPE)

  else
    result = MalMkError(sprintf("unknown builtin '%s'", fn.string))
  endif

  xout result
endop

opcode MalRestParamIndex(params:MalValue):i
  result:i = -1

  if (params.length > 0) then
    for index in [0 ... params.length - 1] do
      param:MalValue = MalAt(params, index)

      if (param.type == $MAL_SYMBOL_TYPE && strcmp(param.string, "&") == 0) then
        result = index
        break
      endif
    od
  endif

  xout result
endop

opcode MalBindFunctionEnv(fn:MalValue, args:MalValue):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  callEnv:MalEnv = MalEnvHandle(-1)
  params:MalValue = MalFunctionParams(fn)
  restIndex:i = MalRestParamIndex(params)
  requiredCount:i = restIndex >= 0 ? restIndex : params.length

  if (restIndex < 0 && args.length != params.length) then
    result = MalMkError(sprintf("fn*: expected %d arguments, got %d", \
      params.length, args.length))
  elseif (restIndex >= 0 && args.length < requiredCount) then
    result = MalMkError(sprintf("fn*: expected at least %d arguments, got %d", \
      requiredCount, args.length))
  elseif (lenarray(fn.env) == 0) then
    result = MalMkError("fn*: missing closure environment")
  else
    closure:MalEnv[] = fn.env
    capturedEnv:MalEnv = MalEnvResolve(closure[0])
    callEnv = MalMkEnvWithOuter(capturedEnv)

    if (requiredCount > 0) then
      for index in [0 ... requiredCount - 1] do
        param:MalValue = MalAt(params, index)
        arg:MalValue = MalAt(args, index)
        callEnv = MalEnvSet(callEnv, param.string, arg)
      od
    endif

    if (restIndex >= 0) then
      restName:MalValue = MalAt(params, restIndex + 1)
      restValues:MalValue = MalMkValue($MAL_LIST_TYPE)

      if (args.length > requiredCount) then
        for index in [requiredCount ... args.length - 1] do
          arg:MalValue = MalAt(args, index)
          restValues = MalAppendValue(restValues, arg)
        od
      endif

      callEnv = MalEnvSet(callEnv, restName.string, restValues)
    endif

  endif

  xout result, callEnv
endop

opcode MalApplyFunction(fn:MalValue, args:MalValue):MalValue
  result:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)

  if (result.type != $MAL_ERROR_TYPE) then
    body:MalValue = MalFunctionBody(fn)
    bodyInputEnv:MalEnv = callEnv
    result, callEnv = EVAL_ENV(body, bodyInputEnv)
  endif

  MalEnvRelease(callEnv)

  xout result
endop

opcode MalApply(fn:MalValue, args:MalValue):MalValue
  if (fn.type == $MAL_BUILTIN_OPERATOR_TYPE) then
    result:MalValue = MalApplyBuiltinOperator(fn, args)
  elseif (fn.type == $MAL_BUILTIN_TYPE) then
    result:MalValue = MalApplyBuiltin(fn, args)
  elseif (fn.type == $MAL_BUILTIN_OPCODE_TYPE) then
    result:MalValue = MalApplyCsoundOpcode(fn, args)
  elseif (fn.type == $MAL_FUNCTION_TYPE) then
    result:MalValue = MalApplyFunction(fn, args)
  elseif (fn.type == $MAL_CSOUND_INSTRUMENT_TYPE) then
    result:MalValue = MalScheduleCsoundInstrument(fn, args, 0, 1)
  else
    result:MalValue = MalMkError(sprintf("cannot apply %s", pr_str(fn)))
  endif

  xout result
endop

opcode MalEvalSequenceEnv(ast:MalValue, env:MalEnv, startIndex:i, resultType:i):(MalValue, MalEnv)
  result:MalValue = MalMkValue(resultType)
  currentEnv:MalEnv = env
  index:i = startIndex
  done:i = 0

  while (index < ast.length && done == 0) do
    value:MalValue = MalAt(ast, index)
    valueInputEnv:MalEnv = currentEnv
    evaluated:MalValue, currentEnv = EVAL_ENV(value, valueInputEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated
      done = 1
    else
      result = MalAppendValue(result, evaluated)
    endif

    index += 1
  od

  xout result, currentEnv
endop

opcode MalUnevaluatedArgs(ast:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_LIST_TYPE)

  if (ast.length > 1) then
    for index in [1 ... ast.length - 1] do
      result = MalAppendValue(result, MalAt(ast, index))
    od
  endif

  xout result
endop

opcode MalEvalHashMapEnv(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)
  currentEnv:MalEnv = env
  index:i = 0
  done:i = 0

  while (index < ast.length && done == 0) do
    key:MalValue = MalAt(ast, index)
    value:MalValue = MalAt(ast, index + 1)
    valueInputEnv:MalEnv = currentEnv
    evaluated:MalValue, currentEnv = EVAL_ENV(value, valueInputEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated
      done = 1
    else
      result = MalMapAssoc(result, key, evaluated)
    endif

    index += 2
  od

  xout result, currentEnv
endop

opcode MalEvalAstEnv(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = ast
  currentEnv:MalEnv = env

  switch ast.type
    case $MAL_SYMBOL_TYPE
      result = MalEnvGet(env, ast.string)

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
  if (ast.length != 2) then
    result:MalValue = MalArityError("quote", 1, ast.length - 1)
  else
    result:MalValue = MalAt(ast, 1)
  endif

  xout result
endop

opcode MalQuasiquoteSequence(ast:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_LIST_TYPE)

  if (ast.length > 0) then
    for offset in [0 ... ast.length - 1] do
      index:i = ast.length - offset - 1
      element:MalValue = MalAt(ast, index)

      if (MalIsForm(element, "splice-unquote") == 1) then
        if (element.length != 2) then
          result = MalArityError("splice-unquote", 1, element.length - 1)
          break
        endif

        result = MalMkList3(MalMkSymbol("concat"), MalAt(element, 1), result)
      else
        quotedElement:MalValue = MalQuasiquote(element)

        if (quotedElement.type == $MAL_ERROR_TYPE) then
          result = quotedElement
          break
        endif

        result = MalMkList3(MalMkSymbol("cons"), quotedElement, result)
      endif
    od
  endif

  xout result
endop

opcode MalQuasiquote(ast:MalValue):MalValue
  result:MalValue = ast

  if (MalIsForm(ast, "unquote") == 1) then
    if (ast.length != 2) then
      result = MalArityError("unquote", 1, ast.length - 1)
    else
      result = MalAt(ast, 1)
    endif
  else
    switch ast.type
      case $MAL_LIST_TYPE
        result = MalQuasiquoteSequence(ast)

      case $MAL_VECTOR_TYPE
        quotedValues:MalValue = MalQuasiquoteSequence(ast)

        if (quotedValues.type == $MAL_ERROR_TYPE) then
          result = quotedValues
        else
          result = MalMkList2(MalMkSymbol("vec"), quotedValues)
        endif

      case $MAL_SYMBOL_TYPE
        result = MalMkList2(MalMkSymbol("quote"), ast)

      case $MAL_HASH_MAP_TYPE
        result = MalMkList2(MalMkSymbol("quote"), ast)
    endsw
  endif

  xout result
endop

opcode MalIsFnForm(value:MalValue):i
  result:i = 0

  if (value.type == $MAL_LIST_TYPE && value.length > 0) then
    head:MalValue = MalAt(value, 0)

    if (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) then
      result = 1
    endif
  endif

  xout result
endop

opcode MalFunctionCaptureEnv(fn:MalValue, env:MalEnv):MalValue
  if (fn.type == $MAL_FUNCTION_TYPE) then
    retainedEnv:MalEnv = MalEnvRetain(env)
    closure:MalEnv[] init 1
    closure[0] = MalEnvHandle(retainedEnv.id)
    fn.env = closure
  endif

  xout fn
endop

opcode MalRefreshTopLevelFunctionClosures(env:MalEnv):MalEnv
  xout env
endop

opcode MalEvalDefinition(ast:MalValue, env:MalEnv, name:S, asMacro:i):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length != 3) then
    result = MalMkError(sprintf("%s: expected 2 arguments, got %d", \
      name, ast.length - 1))
  else
    symbol:MalValue = MalAt(ast, 1)
    valueForm:MalValue = MalAt(ast, 2)

    if (symbol.type != $MAL_SYMBOL_TYPE) then
      result = MalMkError(sprintf("%s: first argument must be a symbol", name))
    else
      definitionInputEnv:MalEnv = currentEnv
      value:MalValue, currentEnv = EVAL_ENV(valueForm, definitionInputEnv)

      if (value.type == $MAL_ERROR_TYPE) then
        result = value
      elseif (asMacro == 1 && value.type != $MAL_FUNCTION_TYPE) then
        result = MalMkError(sprintf("%s: value must be a function", name))
      else
        if (asMacro == 1) then
          value = MalFunctionAsMacro(value)
        endif

        currentEnv = MalEnvSet(currentEnv, symbol.string, value)

        if (MalIsFnForm(valueForm) == 1) then
          value = MalFunctionCaptureEnv(value, currentEnv)
          currentEnv = MalEnvSet(currentEnv, symbol.string, value)
        endif

        currentEnv = MalRefreshTopLevelFunctionClosures(currentEnv)
        value = MalEnvGet(currentEnv, symbol.string)
        result = value
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

  if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) then
    valid = 0
  elseif (params.length > 0) then
    for index in [0 ... params.length - 1] do
      param:MalValue = MalAt(params, index)

      if (param.type != $MAL_SYMBOL_TYPE) then
        valid = 0
        break
      elseif (strcmp(param.string, "&") == 0) then
        if (restIndex >= 0 || index != params.length - 2) then
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
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length != 3) then
    result = MalMkError(sprintf("fn*: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    params:MalValue = MalAt(ast, 1)
    body:MalValue = MalAt(ast, 2)

    if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) then
      result = MalMkError("fn*: params must be list or vector")
    elseif (MalParamsAreValid(params) == 0) then
      result = MalMkError("fn*: params must be symbols")
    else
      result = MalMkFunction(params, body)
      result = MalFunctionCaptureEnv(result, currentEnv)
    endif
  endif

  xout result, currentEnv
endop

opcode MalEvalIf(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length < 3 || ast.length > 4) then
    result = MalMkError(sprintf("if: expected 2 or 3 arguments, got %d", \
      ast.length - 1))
  else
    conditionForm:MalValue = MalAt(ast, 1)
    branchInputEnv:MalEnv = currentEnv
    condition:MalValue, currentEnv = EVAL_ENV(conditionForm, branchInputEnv)

    if (condition.type == $MAL_ERROR_TYPE) then
      result = condition
    elseif (MalIsTruthy(condition) == 1) then
      thenForm:MalValue = MalAt(ast, 2)
      branchInputEnv = currentEnv
      result, currentEnv = EVAL_ENV(thenForm, branchInputEnv)
    elseif (ast.length == 4) then
      elseForm:MalValue = MalAt(ast, 3)
      branchInputEnv = currentEnv
      result, currentEnv = EVAL_ENV(elseForm, branchInputEnv)
    endif
  endif

  xout result, currentEnv
endop

opcode MalEvalDo(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env
  index:i = 1
  done:i = 0

  while (index < ast.length && done == 0) do
    form:MalValue = MalAt(ast, index)
    formInputEnv:MalEnv = currentEnv
    result, currentEnv = EVAL_ENV(form, formInputEnv)

    if (result.type == $MAL_ERROR_TYPE) then
      done = 1
    endif

    index += 1
  od

  xout result, currentEnv
endop

opcode MalEvalLet(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env
  letEnv:MalEnv = MalMkEnvWithOuter(env)

  if (ast.length != 3) then
    result = MalMkError(sprintf("let*: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    bindings:MalValue = MalAt(ast, 1)
    body:MalValue = MalAt(ast, 2)

    if (bindings.type != $MAL_LIST_TYPE && \
        bindings.type != $MAL_VECTOR_TYPE) then
      result = MalMkError("let*: bindings must be list or vector")
    elseif (bindings.length % 2 != 0) then
      result = MalMkError("let*: bindings must contain even number of forms")
    else
      index:i = 0
      done:i = 0

      while (index < bindings.length && done == 0) do
        name:MalValue = MalAt(bindings, index)
        valueForm:MalValue = MalAt(bindings, index + 1)

        if (name.type != $MAL_SYMBOL_TYPE) then
          result = MalMkError("let*: binding name must be a symbol")
          done = 1
        else
          letInputEnv:MalEnv = letEnv
          value:MalValue, letEnv = EVAL_ENV(valueForm, letInputEnv)

          if (value.type == $MAL_ERROR_TYPE) then
            result = value
            done = 1
          else
            letEnv = MalEnvSet(letEnv, name.string, value)

            index += 2
          endif
        endif
      od

      if (done == 0) then
        letInputEnv = letEnv
        result, letEnv = EVAL_ENV(body, letInputEnv)
      endif
    endif
  endif

  MalEnvRelease(letEnv)

  xout result, currentEnv
endop

opcode EVAL_ENV(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = ast
  workAst:MalValue = ast
  evalEnv:MalEnv = env
  returnEnv:MalEnv = env
  recursiveInputEnv:MalEnv = env
  transientEnvs:MalValue = MalMkValue($MAL_LIST_TYPE)
  done:i = 0

  while (done == 0) do
    hasDebug:i = MalEnvHas(evalEnv, "DEBUG-EVAL")

    if (hasDebug == 1) then
      debugValue:MalValue = MalEnvGet(evalEnv, "DEBUG-EVAL")

      if (MalIsTruthy(debugValue) == 1) then
        SdebugAst:S = pr_str(workAst)
        prints "EVAL: %s\n", SdebugAst
      endif
    endif

    if (workAst.type == $MAL_LIST_TYPE && workAst.length > 0) then
      head:MalValue = MalAt(workAst, 0)

      if (MalIsSymbolNamed(head, "quote") == 1) then
        result = MalEvalQuote(workAst)
        done = 1

      elseif (MalIsSymbolNamed(head, "quasiquote") == 1) then
        if (workAst.length != 2) then
          result = MalArityError("quasiquote", 1, workAst.length - 1)
          done = 1
        else
          workAst = MalQuasiquote(MalAt(workAst, 1))

          if (workAst.type == $MAL_ERROR_TYPE) then
            result = workAst
            done = 1
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "def!") == 0) then
        recursiveInputEnv = evalEnv
        result, evalEnv = MalEvalDef(workAst, recursiveInputEnv)
        done = 1

      elseif (MalIsSymbolNamed(head, "defmacro!") == 1) then
        recursiveInputEnv = evalEnv
        result, evalEnv = MalEvalDefMacro(workAst, recursiveInputEnv)
        done = 1

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) then
        recursiveInputEnv = evalEnv
        result, evalEnv = MalEvalFn(workAst, recursiveInputEnv)
        done = 1

      elseif (MalIsSymbolNamed(head, "try*") == 1) then
        tryArgCount:i = workAst.length - 1

        if (tryArgCount < 1 || tryArgCount > 2) then
          result = MalMkError(sprintf( \
            "try*: expected 1 or 2 arguments, got %d", tryArgCount))
          done = 1
        elseif (tryArgCount == 1) then
          workAst = MalAt(workAst, 1)
        else
          catchClause:MalValue = MalAt(workAst, 2)

          if (MalIsForm(catchClause, "catch*") == 0 || \
              catchClause.length != 3) then
            result = MalMkError( \
              "try*: second argument must be (catch* symbol handler)")
            done = 1
          else
            catchBinding:MalValue = MalAt(catchClause, 1)

            if (catchBinding.type != $MAL_SYMBOL_TYPE) then
              result = MalMkError("catch*: binding must be a symbol")
              done = 1
            else
              tryForm:MalValue = MalAt(workAst, 1)
              recursiveInputEnv = evalEnv
              tryResult:MalValue, evalEnv = EVAL_ENV( \
                tryForm, recursiveInputEnv)

              if (tryResult.type == $MAL_ERROR_TYPE) then
                catchEnv:MalEnv = MalMkEnvWithOuter(evalEnv)
                transientEnvs = MalAppendValue( \
                  transientEnvs, MalMkNumber(catchEnv.id))
                catchValue:MalValue = MalErrorPayload(tryResult)
                catchEnv = MalEnvSet( \
                  catchEnv, catchBinding.string, catchValue)
                workAst = MalAt(catchClause, 2)
                evalEnv = catchEnv
              else
                result = tryResult
                done = 1
              endif
            endif
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "if") == 0) then
        if (workAst.length < 3 || workAst.length > 4) then
          result = MalMkError(sprintf("if: expected 2 or 3 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          ifConditionForm:MalValue = MalAt(workAst, 1)
          recursiveInputEnv = evalEnv
          ifCondition:MalValue, evalEnv = EVAL_ENV( \
            ifConditionForm, recursiveInputEnv)

          if (ifCondition.type == $MAL_ERROR_TYPE) then
            result = ifCondition
            done = 1
          elseif (MalIsTruthy(ifCondition) == 1) then
            workAst = MalAt(workAst, 2)
          elseif (workAst.length == 4) then
            workAst = MalAt(workAst, 3)
          else
            result = MalMkValue($MAL_NIL_TYPE)
            done = 1
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "do") == 0) then
        if (workAst.length == 1) then
          result = MalMkValue($MAL_NIL_TYPE)
          done = 1
        else
          doIndex:i = 1
          doError:i = 0
          doLastIndex:i = workAst.length - 1

          while (doIndex < doLastIndex && doError == 0) do
            doForm:MalValue = MalAt(workAst, doIndex)
            recursiveInputEnv = evalEnv
            result, evalEnv = EVAL_ENV(doForm, recursiveInputEnv)

            if (result.type == $MAL_ERROR_TYPE) then
              doError = 1
              done = 1
            endif

            doIndex += 1
          od

          if (doError == 0) then
            workAst = MalAt(workAst, doLastIndex)
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "let*") == 0) then
        letEnv:MalEnv = MalMkEnvWithOuter(evalEnv)
        transientEnvs = MalAppendValue( \
          transientEnvs, MalMkNumber(letEnv.id))

        if (workAst.length != 3) then
          result = MalMkError(sprintf("let*: expected 2 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          letBindings:MalValue = MalAt(workAst, 1)
          letBody:MalValue = MalAt(workAst, 2)

          if (letBindings.type != $MAL_LIST_TYPE && \
              letBindings.type != $MAL_VECTOR_TYPE) then
            result = MalMkError("let*: bindings must be list or vector")
            done = 1
          elseif (letBindings.length % 2 != 0) then
            result = MalMkError("let*: bindings must contain even number of forms")
            done = 1
          else
            letIndex:i = 0
            letError:i = 0

            while (letIndex < letBindings.length && letError == 0) do
              letName:MalValue = MalAt(letBindings, letIndex)
              letValueForm:MalValue = MalAt(letBindings, letIndex + 1)

              if (letName.type != $MAL_SYMBOL_TYPE) then
                result = MalMkError("let*: binding name must be a symbol")
                letError = 1
                done = 1
              else
                recursiveInputEnv = letEnv
                letValue:MalValue, letEnv = EVAL_ENV( \
                  letValueForm, recursiveInputEnv)

                if (letValue.type == $MAL_ERROR_TYPE) then
                  result = letValue
                  letError = 1
                  done = 1
                else
                  letEnv = MalEnvSet(letEnv, letName.string, letValue)

                  letIndex += 2
                endif
              endif
            od

            if (letError == 0) then
              workAst = letBody
              evalEnv = letEnv
            endif
          endif
        endif

      else
        recursiveInputEnv = evalEnv
        fn:MalValue, evalEnv = EVAL_ENV(head, recursiveInputEnv)

        if (fn.type == $MAL_ERROR_TYPE) then
          result = fn
          done = 1
        elseif (MalIsMacro(fn) == 1) then
          rawArgs:MalValue = MalUnevaluatedArgs(workAst)
          expansion:MalValue = MalApplyFunction(fn, rawArgs)

          if (expansion.type == $MAL_ERROR_TYPE) then
            result = expansion
            done = 1
          else
            workAst = expansion
          endif
        else
          recursiveInputEnv = evalEnv
          args:MalValue, evalEnv = MalEvalSequenceEnv( \
            workAst, recursiveInputEnv, 1, $MAL_LIST_TYPE)

          if (args.type == $MAL_ERROR_TYPE) then
            result = args
            done = 1
          elseif (fn.type == $MAL_BUILTIN_TYPE && strcmp(fn.string, "eval") == 0) then
            if (args.length != 1) then
              result = MalArityError(fn.string, 1, args.length)
              done = 1
            else
              evalAst:MalValue = MalAt(args, 0)
              evalRoot:MalEnv = MalEnvRoot(evalEnv)
              recursiveInputEnv = evalRoot
              result, evalRoot = EVAL_ENV(evalAst, recursiveInputEnv)
              evalEnv = MalEnvSetRoot(evalEnv, evalRoot)

              done = 1
            endif
          elseif (fn.type == $MAL_FUNCTION_TYPE) then
            bindStatus:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)

            if (bindStatus.type == $MAL_ERROR_TYPE) then
              result = bindStatus
              done = 1
            else
              transientEnvs = MalAppendValue( \
                transientEnvs, MalMkNumber(callEnv.id))
              workAst = MalFunctionBody(fn)
              evalEnv = callEnv
            endif
          else
            result = MalApply(fn, args)
            done = 1
          endif
        endif
      endif
    else
      recursiveInputEnv = evalEnv
      result, evalEnv = MalEvalAstEnv(workAst, recursiveInputEnv)

      done = 1
    endif
  od

  returnEnv = MalEnvResolve(returnEnv)

  if (transientEnvs.length > 0) then
    for releaseIndex in [0 ... transientEnvs.length - 1] do
      reverseIndex:i = transientEnvs.length - releaseIndex - 1
      envValue:MalValue = MalAt(transientEnvs, reverseIndex)
      envId:i = envValue.number
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
  ast:MalValue = read_str(source)
  currentEnv:MalEnv = env

  if (ast.type == $MAL_ERROR_TYPE) then
    result:MalValue = ast
  else
    sourceInputEnv:MalEnv = currentEnv
    result, currentEnv = EVAL_ENV(ast, sourceInputEnv)
  endif

  xout result, currentEnv
endop

opcode MalMkStep6Env():MalEnv
  env:MalEnv = MalMkStep2Env()
  env = MalEnvSet(env, "*ARGV*", MalMkValue($MAL_LIST_TYPE))
  source:S = "(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \"\\nnil)\")))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) then
    prints "load-file bootstrap failed: %s\n", result.string
  endif

  xout env
endop

opcode MalMkStep8Env():MalEnv
  env:MalEnv = MalMkStep6Env()
  source:S = "(defmacro! cond (fn* (& xs) (if (> (count xs) 0) "
  source strcat source, "(list 'if (first xs) "
  source strcat source, "(if (> (count xs) 1) (nth xs 1) "
  source strcat source, "(throw \"odd number of forms to cond\")) "
  source strcat source, "(cons 'cond (rest (rest xs)))))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) then
    prints "cond bootstrap failed: %s\n", result.string
  endif

  xout env
endop

opcode MalMkStep9Env():MalEnv
  env:MalEnv = MalMkStep8Env()
  env = MalEnvSet(env, "throw", MalMkBuiltin("throw"))
  env = MalEnvSet(env, "apply", MalMkBuiltin("apply"))
  env = MalEnvSet(env, "map", MalMkBuiltin("map"))
  env = MalEnvSet(env, "nil?", MalMkBuiltin("nil?"))
  env = MalEnvSet(env, "true?", MalMkBuiltin("true?"))
  env = MalEnvSet(env, "false?", MalMkBuiltin("false?"))
  env = MalEnvSet(env, "symbol", MalMkBuiltin("symbol"))
  env = MalEnvSet(env, "symbol?", MalMkBuiltin("symbol?"))
  env = MalEnvSet(env, "keyword", MalMkBuiltin("keyword"))
  env = MalEnvSet(env, "keyword?", MalMkBuiltin("keyword?"))
  env = MalEnvSet(env, "vector", MalMkBuiltin("vector"))
  env = MalEnvSet(env, "vector?", MalMkBuiltin("vector?"))
  env = MalEnvSet(env, "sequential?", MalMkBuiltin("sequential?"))
  env = MalEnvSet(env, "hash-map", MalMkBuiltin("hash-map"))
  env = MalEnvSet(env, "map?", MalMkBuiltin("map?"))
  env = MalEnvSet(env, "assoc", MalMkBuiltin("assoc"))
  env = MalEnvSet(env, "dissoc", MalMkBuiltin("dissoc"))
  env = MalEnvSet(env, "get", MalMkBuiltin("get"))
  env = MalEnvSet(env, "contains?", MalMkBuiltin("contains?"))
  env = MalEnvSet(env, "keys", MalMkBuiltin("keys"))
  env = MalEnvSet(env, "vals", MalMkBuiltin("vals"))
  env = MalEnvSet(env, "pr-str", MalMkBuiltin("pr-str"))
  env = MalRefreshTopLevelFunctionClosures(env)
  xout env
endop

opcode MalMkStepAEnv():MalEnv
  env:MalEnv = MalMkStep9Env()
  env = MalEnvSet(env, "meta", MalMkBuiltin("meta"))
  env = MalEnvSet(env, "with-meta", MalMkBuiltin("with-meta"))
  env = MalEnvSet(env, "string?", MalMkBuiltin("string?"))
  env = MalEnvSet(env, "number?", MalMkBuiltin("number?"))
  env = MalEnvSet(env, "fn?", MalMkBuiltin("fn?"))
  env = MalEnvSet(env, "seq", MalMkBuiltin("seq"))
  env = MalEnvSet(env, "conj", MalMkBuiltin("conj"))
  env = MalEnvSet(env, "time-ms", MalMkBuiltin("time-ms"))
  env = MalEnvSet(env, "println", MalMkBuiltin("println"))
  env = MalEnvSet(env, "readline", MalMkBuiltin("readline"))
  source:S = "(def! *host-language* \"Csound7\")"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) then
    prints "host language bootstrap failed: %s\n", result.string
  endif

  xout env
endop

opcode MalMkCsoundEnv():MalEnv
  env:MalEnv = MalMkStepAEnv()
  env = MalEnvSet(env, "csound-eval", MalMkBuiltin("csound-eval"))
  env = MalEnvSet(env, "csound/param-bindings", \
    MalMkBuiltin("csound/param-bindings"))
  env = MalEnvSet(env, "csound/compile-inst", \
    MalMkBuiltin("csound/compile-inst"))
  env = MalEnvSet(env, "csound/event", MalMkBuiltin("csound/event"))
  env = MalEnvSet(env, "csound/cpsmidinn", MalMkCsoundOpcode( \
    "cpsmidinn", $MAL_CSOUND_EXPRESSION_NODE, 1, 1))
  env = MalEnvSet(env, "csound/pluck", MalMkCsoundOpcode( \
    "pluck", $MAL_CSOUND_AUDIO_NODE, 5, 7))
  env = MalEnvSet(env, "csound/poscil", MalMkCsoundOpcode( \
    "poscil", $MAL_CSOUND_AUDIO_NODE, 2, 4))
  env = MalEnvSet(env, "csound/linseg", MalMkCsoundOpcode( \
    "linseg", $MAL_CSOUND_AUDIO_NODE, 3, 33))
  env = MalEnvSet(env, "csound/tone", MalMkCsoundOpcode( \
    "tone", $MAL_CSOUND_AUDIO_NODE, 2, 2))
  env = MalEnvSet(env, "csound/pan2", MalMkCsoundOpcode( \
    "pan2", $MAL_CSOUND_AUDIO_PAIR_NODE, 2, 2))
  env = MalEnvSet(env, "csound/outs", MalMkCsoundOpcode( \
    "outs", $MAL_CSOUND_STATEMENT_NODE, 1, 2))

  source:S = "(defmacro! definst (fn* (name params body) (list 'def! name (list 'csound/compile-inst (list 'quote name) (list 'quote params) (list 'let* (csound/param-bindings params) body)))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) then
    prints "definst bootstrap failed: %s\n", result.string
  endif

  xout env
endop
