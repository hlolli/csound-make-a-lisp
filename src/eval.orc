declare EVAL_ENV(result:MalValue, nextEnv:MalEnv):(MalValue, MalEnv)
declare MalEquals(left:MalValue, right:MalValue):i

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

opcode MalArityError(name:S, expected:i, actual:i):MalValue
  result:MalValue = MalMkError(sprintf("%s: expected %d arguments, got %d", \
    name, expected, actual))
  xout result
endop

opcode MalNumberComparison(name:S, left:i, right:i):i
  result:i = 0

  if (strcmp(name, ">") == 0) then
    result = left > right ? 1 : 0
  elseif (strcmp(name, ">=") == 0) then
    result = left >= right ? 1 : 0
  elseif (strcmp(name, "<") == 0) then
    result = left < right ? 1 : 0
  elseif (strcmp(name, "<=") == 0) then
    result = left <= right ? 1 : 0
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
        result = left.number == right.number ? 1 : 0

      case $MAL_STRING_TYPE
        result = strcmp(left.string, right.string) == 0 ? 1 : 0

      case $MAL_KEYWORD_TYPE
        result = strcmp(left.string, right.string) == 0 ? 1 : 0

      case $MAL_SYMBOL_TYPE
        result = strcmp(left.string, right.string) == 0 ? 1 : 0

      case $MAL_NIL_TYPE
        result = 1

      case $MAL_TRUE_TYPE
        result = 1

      case $MAL_FALSE_TYPE
        result = 1
    endsw
  endif

  xout result
endop

opcode MalApplyBuiltin(fn:MalValue, args:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_NIL_TYPE)

  if (strcmp(fn.string, "list") == 0) then
    result = args

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

opcode MalEvalDef(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length != 3) then
    result = MalMkError(sprintf("def!: expected 2 arguments, got %d", \
      ast.length - 1))
  else
    symbol:MalValue = ast.list[1]
    valueForm:MalValue = ast.list[2]

    if (symbol.type != $MAL_SYMBOL_TYPE) then
      result = MalMkError("def!: first argument must be a symbol")
    else
      value:MalValue, currentEnv = EVAL_ENV(valueForm, currentEnv)

      if (value.type == $MAL_ERROR_TYPE) then
        result = value
      else
        currentEnv = MalEnvSet(currentEnv, symbol.string, value)

        if (MalIsFnForm(valueForm) == 1) then
          value = MalFunctionCaptureEnv(value, currentEnv)
          currentEnv = MalEnvSet(currentEnv, symbol.string, value)
        endif

        result = value
      endif
    endif
  endif

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
  currentEnv:MalEnv = env

  if (ast.type == $MAL_LIST_TYPE && ast.length > 0) then
    head:MalValue = ast.list[0]

    if (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "def!") == 0) then
      result, currentEnv = MalEvalDef(ast, currentEnv)
    elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "let*") == 0) then
      result, currentEnv = MalEvalLet(ast, currentEnv)
    elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "if") == 0) then
      result, currentEnv = MalEvalIf(ast, currentEnv)
    elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "do") == 0) then
      result, currentEnv = MalEvalDo(ast, currentEnv)
    elseif (head.type == $MAL_SYMBOL_TYPE && strcmp(head.string, "fn*") == 0) then
      result, currentEnv = MalEvalFn(ast, currentEnv)
    else
      evaluatedList:MalValue = MalMkValue($MAL_NIL_TYPE)
      evaluatedList, currentEnv = MalEvalAstEnv(ast, currentEnv)

      if (evaluatedList.type == $MAL_ERROR_TYPE) then
        result = evaluatedList
      else
        fn:MalValue = evaluatedList.list[0]
        args:MalValue = MalMkValue($MAL_LIST_TYPE)

        if (evaluatedList.length > 1) then
          for argIndex in [1 ... evaluatedList.length - 1] do
            arg:MalValue = evaluatedList.list[argIndex]
            args = MalAppendValue(args, arg)
          od
        endif

        result = MalApply(fn, args)
      endif
    endif
  else
    result, currentEnv = MalEvalAstEnv(ast, currentEnv)
  endif

  xout result, currentEnv
endop

opcode EVAL(ast:MalValue, env:MalEnv):MalValue
  result:MalValue, updatedEnv:MalEnv = EVAL_ENV(ast, env)
  xout result
endop
