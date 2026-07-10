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
    leftArg:MalValue = args.list[0]
    rightArg:MalValue = args.list[1]
    left:i = leftArg.number
    right:i = rightArg.number

    if (leftArg.type != $MAL_NUMBER_TYPE || \
        rightArg.type != $MAL_NUMBER_TYPE) then
      result = MalMkError(sprintf("%s: expected numeric arguments", fn.string))
    else
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
    head:MalValue = ast.list[0]
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
      values[index] = value.list[index]
    od
  endif

  result:MalValue = MalMkValue(resultType)
  result.list = values
  result.length = value.length
  xout result
endop

opcode MalArityError(name:S, expected:i, actual:i):MalValue
  result:MalValue = MalMkError(sprintf("%s: expected %d arguments, got %d", \
    name, expected, actual))
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
    leftArg:MalValue = args.list[0]
    rightArg:MalValue = args.list[1]

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
          leftItem:MalValue = left.list[index]
          rightItem:MalValue = right.list[index]

          if (MalEquals(leftItem, rightItem) == 0) then
            result = 0
            break
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

  if (strcmp(fn.string, "list") == 0) then
    result = args

  elseif (strcmp(fn.string, "cons") == 0) then
    if (args.length != 2) then
      result = MalArityError(fn.string, 2, args.length)
    else
      first:MalValue = args.list[0]
      sequence:MalValue = args.list[1]

      if (MalIsSequential(sequence) == 0) then
        result = MalMkError("cons: second argument must be list or vector")
      else
        resultLength:i = sequence.length + 1
        values:MalValue[] init resultLength
        values[0] = first

        if (sequence.length > 0) then
          for index in [0 ... sequence.length - 1] do
            values[index + 1] = sequence.list[index]
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
        sequence:MalValue = args.list[index]

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
          sequence:MalValue = args.list[sequenceIndex]

          if (sequence.length > 0) then
            for valueIndex in [0 ... sequence.length - 1] do
              values[destinationIndex] = sequence.list[valueIndex]
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
      sequence:MalValue = args.list[0]

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
      sequence:MalValue = args.list[0]
      indexValue:MalValue = args.list[1]

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
        result = sequence.list[index]
      endif
    endif

  elseif (strcmp(fn.string, "first") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue = args.list[0]

      if (sequence.type == $MAL_NIL_TYPE || \
          (MalIsSequential(sequence) == 1 && sequence.length == 0)) then
        result = MalMkValue($MAL_NIL_TYPE)
      elseif (MalIsSequential(sequence) == 0) then
        result = MalMkError("first: expected list, vector, or nil")
      else
        result = sequence.list[0]
      endif
    endif

  elseif (strcmp(fn.string, "rest") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      sequence:MalValue = args.list[0]

      if (sequence.type != $MAL_NIL_TYPE && MalIsSequential(sequence) == 0) then
        result = MalMkError("rest: expected list, vector, or nil")
      else
        result = MalMkValue($MAL_LIST_TYPE)

        if (sequence.type != $MAL_NIL_TYPE && sequence.length > 1) then
          restLength:i = sequence.length - 1
          values:MalValue[] init restLength

          for index in [0 ... restLength - 1] do
            values[index] = sequence.list[index + 1]
          od

          result.list = values
          result.length = restLength
        endif
      endif
    endif

  elseif (strcmp(fn.string, "list?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = args.list[0]
      result = MalMkBool(value.type == $MAL_LIST_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "empty?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = args.list[0]
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
      value:MalValue = args.list[0]
      result = MalMkValue($MAL_NUMBER_TYPE)

      if (value.type == $MAL_NIL_TYPE) then
        result.number = 0
      elseif (value.type == $MAL_LIST_TYPE || \
              value.type == $MAL_VECTOR_TYPE || \
              value.type == $MAL_HASH_MAP_TYPE) then
        result.number = value.length
      else
        result = MalMkError("count: expected sequence or nil")
      endif
    endif

  elseif (strcmp(fn.string, "str") == 0) then
    output:S = ""

    if (args.length > 0) then
      for index in [0 ... args.length - 1] do
        output strcat output, pr_str_with_readability(args.list[index], 0)
      od
    endif

    result = MalMkString(output)

  elseif (strcmp(fn.string, "read-string") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = args.list[0]

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
      value:MalValue = args.list[0]

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
      result = MalMkAtom(args.list[0])
    endif

  elseif (strcmp(fn.string, "atom?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      value:MalValue = args.list[0]
      result = MalMkBool(value.type == $MAL_ATOM_TYPE ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "deref") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      atom:MalValue = args.list[0]

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
      atom:MalValue = args.list[0]

      if (atom.type != $MAL_ATOM_TYPE) then
        result = MalMkError("reset!: first argument must be an atom")
      else
        value:MalValue = args.list[1]
        result = MalAtomSetValue(atom, value)
      endif
    endif

  elseif (strcmp(fn.string, "swap!") == 0) then
    if (args.length < 2) then
      result = MalMkError(sprintf("swap!: expected at least 2 arguments, got %d", \
        args.length))
    else
      atom:MalValue = args.list[0]

      if (atom.type != $MAL_ATOM_TYPE) then
        result = MalMkError("swap!: first argument must be an atom")
      else
        applyFn:MalValue = args.list[1]
        applyArgs:MalValue = MalMkValue($MAL_LIST_TYPE)
        applyArgs = MalAppendValue(applyArgs, MalAtomValue(atom))

        if (args.length > 2) then
          for index in [2 ... args.length - 1] do
            applyArgs = MalAppendValue(applyArgs, args.list[index])
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
      left:MalValue = args.list[0]
      right:MalValue = args.list[1]
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
      value:MalValue = args.list[0]
      result = MalMkBool(MalIsTruthy(value) == 0 ? 1 : 0)
    endif

  elseif (strcmp(fn.string, "macro?") == 0) then
    if (args.length != 1) then
      result = MalArityError(fn.string, 1, args.length)
    else
      result = MalMkBool(MalIsMacro(args.list[0]))
    endif

  elseif (strcmp(fn.string, "prn") == 0) then
    output:S = ""

    if (args.length > 0) then
      for index in [0 ... args.length - 1] do
        if (index > 0) then
          output strcat output, " "
        endif

        output strcat output, pr_str(args.list[index])
      od
    endif

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
      param:MalValue = params.list[index]

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
  callEnv:MalEnv = MalMkEnv()
  params:MalValue = fn.list[0]
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
    capturedEnv:MalEnv = closure[0]
    callEnv = MalMkEnvWithOuter(capturedEnv)

    if (requiredCount > 0) then
      for index in [0 ... requiredCount - 1] do
        param:MalValue = params.list[index]
        arg:MalValue = args.list[index]
        callEnv = MalEnvSet(callEnv, param.string, arg)
      od
    endif

    if (restIndex >= 0) then
      restName:MalValue = params.list[restIndex + 1]
      restValues:MalValue = MalMkValue($MAL_LIST_TYPE)

      if (args.length > requiredCount) then
        for index in [requiredCount ... args.length - 1] do
          arg:MalValue = args.list[index]
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
    body:MalValue = fn.list[1]
    result, callEnv = EVAL_ENV(body, callEnv)
  endif

  xout result
endop

opcode MalApply(fn:MalValue, args:MalValue):MalValue
  if (fn.type == $MAL_BUILTIN_OPERATOR_TYPE) then
    result:MalValue = MalApplyBuiltinOperator(fn, args)
  elseif (fn.type == $MAL_BUILTIN_TYPE) then
    result:MalValue = MalApplyBuiltin(fn, args)
  elseif (fn.type == $MAL_FUNCTION_TYPE) then
    result:MalValue = MalApplyFunction(fn, args)
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
    value:MalValue = ast.list[index]
    evaluated:MalValue, currentEnv = EVAL_ENV(value, currentEnv)

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
      result = MalAppendValue(result, ast.list[index])
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
    key:MalValue = ast.list[index]
    value:MalValue = ast.list[index + 1]
    evaluated:MalValue, currentEnv = EVAL_ENV(value, currentEnv)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated
      done = 1
    else
      result = MalAppendValue(result, key)
      result = MalAppendValue(result, evaluated)
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
    result:MalValue = ast.list[1]
  endif

  xout result
endop

opcode MalQuasiquoteSequence(ast:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_LIST_TYPE)

  if (ast.length > 0) then
    for offset in [0 ... ast.length - 1] do
      index:i = ast.length - offset - 1
      element:MalValue = ast.list[index]

      if (MalIsForm(element, "splice-unquote") == 1) then
        if (element.length != 2) then
          result = MalArityError("splice-unquote", 1, element.length - 1)
          break
        endif

        result = MalMkList3(MalMkSymbol("concat"), element.list[1], result)
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
      result = ast.list[1]
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
    head:MalValue = value.list[0]

    if (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) then
      result = 1
    endif
  endif

  xout result
endop

opcode MalFunctionCaptureEnv(fn:MalValue, env:MalEnv):MalValue
  if (fn.type == $MAL_FUNCTION_TYPE) then
    closure:MalEnv[] init 1
    closure[0] = env
    fn.env = closure
  endif

  xout fn
endop

opcode MalRefreshTopLevelFunctionClosures(env:MalEnv):MalEnv
  if (env.length > 0) then
    for index in [0 ... env.length - 1] do
      value:MalValue = env.values[index]

      if (value.type == $MAL_FUNCTION_TYPE && lenarray(value.env) > 0) then
        closure:MalEnv[] = value.env
        capturedEnv:MalEnv = closure[0]

        if (lenarray(capturedEnv.outer) == 0) then
          value = MalFunctionCaptureEnv(value, env)
          env = MalEnvSet(env, env.keys[index], value)
        endif
      endif
    od
  endif

  xout env
endop

opcode MalEvalDefinition(ast:MalValue, env:MalEnv, name:S, asMacro:i):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length != 3) then
    result = MalMkError(sprintf("%s: expected 2 arguments, got %d", \
      name, ast.length - 1))
  else
    symbol:MalValue = ast.list[1]
    valueForm:MalValue = ast.list[2]

    if (symbol.type != $MAL_SYMBOL_TYPE) then
      result = MalMkError(sprintf("%s: first argument must be a symbol", name))
    else
      value:MalValue, currentEnv = EVAL_ENV(valueForm, currentEnv)

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
      param:MalValue = params.list[index]

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
    params:MalValue = ast.list[1]
    body:MalValue = ast.list[2]

    if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) then
      result = MalMkError("fn*: params must be list or vector")
    elseif (MalParamsAreValid(params) == 0) then
      result = MalMkError("fn*: params must be symbols")
    else
      closure:MalEnv[] init 1
      closure[0] = currentEnv
      result = MalMkFunctionWithEnv(params, body, closure)
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
    conditionForm:MalValue = ast.list[1]
    condition:MalValue, currentEnv = EVAL_ENV(conditionForm, currentEnv)

    if (condition.type == $MAL_ERROR_TYPE) then
      result = condition
    elseif (MalIsTruthy(condition) == 1) then
      thenForm:MalValue = ast.list[2]
      result, currentEnv = EVAL_ENV(thenForm, currentEnv)
    elseif (ast.length == 4) then
      elseForm:MalValue = ast.list[3]
      result, currentEnv = EVAL_ENV(elseForm, currentEnv)
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
    form:MalValue = ast.list[index]
    result, currentEnv = EVAL_ENV(form, currentEnv)

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
  directFnNames:S[] init 0
  directFnCount:i = 0

  if (ast.length != 3) then
    result = MalMkError(sprintf("let*: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    bindings:MalValue = ast.list[1]
    body:MalValue = ast.list[2]

    if (bindings.type != $MAL_LIST_TYPE && \
        bindings.type != $MAL_VECTOR_TYPE) then
      result = MalMkError("let*: bindings must be list or vector")
    elseif (bindings.length % 2 != 0) then
      result = MalMkError("let*: bindings must contain even number of forms")
    else
      index:i = 0
      done:i = 0

      while (index < bindings.length && done == 0) do
        name:MalValue = bindings.list[index]
        valueForm:MalValue = bindings.list[index + 1]

        if (name.type != $MAL_SYMBOL_TYPE) then
          result = MalMkError("let*: binding name must be a symbol")
          done = 1
        else
          value:MalValue, letEnv = EVAL_ENV(valueForm, letEnv)

          if (value.type == $MAL_ERROR_TYPE) then
            result = value
            done = 1
          else
            letEnv = MalEnvSet(letEnv, name.string, value)

            if (MalIsFnForm(valueForm) == 1) then
              directFnNames[directFnCount] = name.string
              directFnCount += 1
            endif

            if (directFnCount > 0) then
              for fnIndex in [0 ... directFnCount - 1] do
                fnName:S = directFnNames[fnIndex]
                fnValue:MalValue = MalEnvGet(letEnv, fnName)
                fnValue = MalFunctionCaptureEnv(fnValue, letEnv)
                letEnv = MalEnvSet(letEnv, fnName, fnValue)
              od
            endif

            index += 2
          endif
        endif
      od

      if (done == 0) then
        result, letEnv = EVAL_ENV(body, letEnv)
      endif
    endif
  endif

  xout result, currentEnv
endop

opcode EVAL_ENV(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = ast
  workAst:MalValue = ast
  evalEnv:MalEnv = env
  returnEnv:MalEnv = env
  done:i = 0
  preserveReturnEnv:i = 0

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
      head:MalValue = workAst.list[0]

      if (MalIsSymbolNamed(head, "quote") == 1) then
        result = MalEvalQuote(workAst)
        done = 1

      elseif (MalIsSymbolNamed(head, "quasiquote") == 1) then
        if (workAst.length != 2) then
          result = MalArityError("quasiquote", 1, workAst.length - 1)
          done = 1
        else
          workAst = MalQuasiquote(workAst.list[1])

          if (workAst.type == $MAL_ERROR_TYPE) then
            result = workAst
            done = 1
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "def!") == 0) then
        result, evalEnv = MalEvalDef(workAst, evalEnv)
        if (preserveReturnEnv == 0) then
          returnEnv = evalEnv
        endif
        done = 1

      elseif (MalIsSymbolNamed(head, "defmacro!") == 1) then
        result, evalEnv = MalEvalDefMacro(workAst, evalEnv)
        if (preserveReturnEnv == 0) then
          returnEnv = evalEnv
        endif
        done = 1

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) then
        result, evalEnv = MalEvalFn(workAst, evalEnv)
        if (preserveReturnEnv == 0) then
          returnEnv = evalEnv
        endif
        done = 1

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "if") == 0) then
        if (workAst.length < 3 || workAst.length > 4) then
          result = MalMkError(sprintf("if: expected 2 or 3 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          ifConditionForm:MalValue = workAst.list[1]
          ifCondition:MalValue, evalEnv = EVAL_ENV(ifConditionForm, evalEnv)

          if (preserveReturnEnv == 0) then
            returnEnv = evalEnv
          elseif (preserveReturnEnv == 1) then
            returnEnv = MalEnvRoot(evalEnv)
          endif

          if (ifCondition.type == $MAL_ERROR_TYPE) then
            result = ifCondition
            done = 1
          elseif (MalIsTruthy(ifCondition) == 1) then
            workAst = workAst.list[2]
          elseif (workAst.length == 4) then
            workAst = workAst.list[3]
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
            doForm:MalValue = workAst.list[doIndex]
            result, evalEnv = EVAL_ENV(doForm, evalEnv)

            if (preserveReturnEnv == 0) then
              returnEnv = evalEnv
            elseif (preserveReturnEnv == 1) then
              returnEnv = MalEnvRoot(evalEnv)
            endif

            if (result.type == $MAL_ERROR_TYPE) then
              doError = 1
              done = 1
            endif

            doIndex += 1
          od

          if (doError == 0) then
            workAst = workAst.list[doLastIndex]
          endif
        endif

      elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "let*") == 0) then
        letEnv:MalEnv = MalMkEnvWithOuter(evalEnv)
        letDirectFnNames:S[] init 0
        letDirectFnCount:i = 0

        if (workAst.length != 3) then
          result = MalMkError(sprintf("let*: expected 2 arguments, got %d", \
            workAst.length - 1))
          done = 1
        else
          letBindings:MalValue = workAst.list[1]
          letBody:MalValue = workAst.list[2]

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
              letName:MalValue = letBindings.list[letIndex]
              letValueForm:MalValue = letBindings.list[letIndex + 1]

              if (letName.type != $MAL_SYMBOL_TYPE) then
                result = MalMkError("let*: binding name must be a symbol")
                letError = 1
                done = 1
              else
                letValue:MalValue, letEnv = EVAL_ENV(letValueForm, letEnv)

                if (letValue.type == $MAL_ERROR_TYPE) then
                  result = letValue
                  letError = 1
                  done = 1
                else
                  letEnv = MalEnvSet(letEnv, letName.string, letValue)

                  if (MalIsFnForm(letValueForm) == 1) then
                    letDirectFnNames[letDirectFnCount] = letName.string
                    letDirectFnCount += 1
                  endif

                  if (letDirectFnCount > 0) then
                    for letFnIndex in [0 ... letDirectFnCount - 1] do
                      letFnName:S = letDirectFnNames[letFnIndex]
                      letFnValue:MalValue = MalEnvGet(letEnv, letFnName)
                      letFnValue = MalFunctionCaptureEnv(letFnValue, letEnv)
                      letEnv = MalEnvSet(letEnv, letFnName, letFnValue)
                    od
                  endif

                  letIndex += 2
                endif
              endif
            od

            if (letError == 0) then
              workAst = letBody
              evalEnv = letEnv
              preserveReturnEnv = 1
            endif
          endif
        endif

      else
        fn:MalValue, evalEnv = EVAL_ENV(head, evalEnv)

        if (preserveReturnEnv == 0) then
          returnEnv = evalEnv
        elseif (preserveReturnEnv == 1) then
          returnEnv = MalEnvRoot(evalEnv)
        endif

        if (fn.type == $MAL_ERROR_TYPE) then
          result = fn
          done = 1
        elseif (MalIsMacro(fn) == 1) then
          rawArgs:MalValue = MalUnevaluatedArgs(workAst)
          expansion:MalValue = MalApply(fn, rawArgs)

          if (expansion.type == $MAL_ERROR_TYPE) then
            result = expansion
            done = 1
          else
            workAst = expansion
          endif
        else
          args:MalValue, evalEnv = MalEvalSequenceEnv( \
            workAst, evalEnv, 1, $MAL_LIST_TYPE)

          if (preserveReturnEnv == 0) then
            returnEnv = evalEnv
          elseif (preserveReturnEnv == 1) then
            returnEnv = MalEnvRoot(evalEnv)
          endif

          if (args.type == $MAL_ERROR_TYPE) then
            result = args
            done = 1
          elseif (fn.type == $MAL_BUILTIN_TYPE && strcmp(fn.string, "eval") == 0) then
            if (args.length != 1) then
              result = MalArityError(fn.string, 1, args.length)
              done = 1
            else
              evalAst:MalValue = args.list[0]
              evalRoot:MalEnv = MalEnvRoot(evalEnv)
              result, evalRoot = EVAL_ENV(evalAst, evalRoot)
              evalEnv = MalEnvSetRoot(evalEnv, evalRoot)
              if (preserveReturnEnv == 1) then
                returnEnv = evalRoot
              else
                returnEnv = evalEnv
              endif

              done = 1
            endif
          elseif (fn.type == $MAL_FUNCTION_TYPE) then
            bindStatus:MalValue, callEnv:MalEnv = MalBindFunctionEnv(fn, args)

            if (bindStatus.type == $MAL_ERROR_TYPE) then
              result = bindStatus
              done = 1
            else
              workAst = fn.list[1]
              evalEnv = callEnv
              preserveReturnEnv = 2
            endif
          else
            result = MalApply(fn, args)
            done = 1
          endif
        endif
      endif
    else
      result, evalEnv = MalEvalAstEnv(workAst, evalEnv)

      if (preserveReturnEnv == 0) then
        returnEnv = evalEnv
      elseif (preserveReturnEnv == 1) then
        returnEnv = MalEnvRoot(evalEnv)
      endif

      done = 1
    endif
  od

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
    result, currentEnv = EVAL_ENV(ast, currentEnv)
  endif

  xout result, currentEnv
endop

opcode MalMkStep6Env():MalEnv
  env:MalEnv = MalMkStep2Env()
  source:S = "(def! load-file (fn* (f) (eval (read-string (str \"(do \" (slurp f) \"\\nnil)\")))))"
  result:MalValue, env = MalEvalSourceEnv(source, env)

  if (result.type == $MAL_ERROR_TYPE) then
    prints "load-file bootstrap failed: %s\n", result.string
  endif

  xout env
endop
