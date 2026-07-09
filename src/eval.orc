declare EVAL_ENV(result:MalValue, nextEnv:MalEnv):(MalValue, MalEnv)

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

opcode MalApply(fn:MalValue, args:MalValue):MalValue
  if (fn.type == $MAL_BUILTIN_OPERATOR_TYPE) then
    result:MalValue = MalApplyBuiltinOperator(fn, args)
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

opcode MalEvalDef(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = MalMkValue($MAL_NIL_TYPE)
  currentEnv:MalEnv = env

  if (ast.length != 3) then
    result = MalMkError(sprintf("def!: expected 2 arguments, got %d", \
      ast.length - 1))
  elseif (ast.list[1].type != $MAL_SYMBOL_TYPE) then
    result = MalMkError("def!: first argument must be a symbol")
  else
    value:MalValue, currentEnv = EVAL_ENV(ast.list[2], currentEnv)

    if (value.type == $MAL_ERROR_TYPE) then
      result = value
    else
      currentEnv = MalEnvSet(currentEnv, ast.list[1].string, value)
      result = value
    endif
  endif

  xout result, currentEnv
endop

opcode EVAL_ENV(ast:MalValue, env:MalEnv):(MalValue, MalEnv)
  result:MalValue = ast
  currentEnv:MalEnv = env

  if (ast.type == $MAL_LIST_TYPE && ast.length > 0) then
    first:MalValue = ast.list[0]

    if (first.type == $MAL_SYMBOL_TYPE && strcmp(first.string, "def!") == 0) then
      result, currentEnv = MalEvalDef(ast, currentEnv)
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
            args = MalAppendValue(args, evaluatedList.list[argIndex])
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
