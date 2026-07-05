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
    elseif (strcmp(fn.string, "+") == 0) then
      result.number = left + right
    elseif (strcmp(fn.string, "-") == 0) then
      result.number = left - right
    elseif (strcmp(fn.string, "*") == 0) then
      result.number = left * right
    elseif (strcmp(fn.string, "/") == 0) then
      if (right == 0) then
        result = MalMkError("/: division by zero")
      else
        result.number = int(left / right)
      endif
    else
      result = MalMkError(sprintf("unknown builtin operator '%s'", fn.string))
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

opcode EVAL(ast:MalValue, env:MalEnv):MalValue
  result:MalValue = ast

  if (ast.type == $MAL_SYMBOL_TYPE) then
    result = MalEnvGet(env, ast.string)

  elseif (ast.type == $MAL_VECTOR_TYPE) then
    result = MalMkValue($MAL_VECTOR_TYPE)
    vectorIndex:i = 0
    vectorError:i = 0

    while (vectorIndex < ast.length && vectorError == 0) do
      vectorValue:MalValue = ast.list[vectorIndex]
      vectorEvaluated:MalValue = EVAL(vectorValue, env)

      if (vectorEvaluated.type == $MAL_ERROR_TYPE) then
        result = vectorEvaluated
        vectorError = 1
      else
        result = MalAppendValue(result, vectorEvaluated)
      endif

      vectorIndex += 1
    od

  elseif (ast.type == $MAL_HASH_MAP_TYPE) then
    result = MalMkValue($MAL_HASH_MAP_TYPE)
    hashIndex:i = 0
    hashError:i = 0

    while (hashIndex < ast.length && hashError == 0) do
      hashKey:MalValue = ast.list[hashIndex]
      hashValue:MalValue = ast.list[hashIndex + 1]
      hashEvaluated:MalValue = EVAL(hashValue, env)

      if (hashEvaluated.type == $MAL_ERROR_TYPE) then
        result = hashEvaluated
        hashError = 1
      else
        result = MalAppendValue(result, hashKey)
        result = MalAppendValue(result, hashEvaluated)
      endif

      hashIndex += 2
    od

  elseif (ast.type == $MAL_LIST_TYPE && ast.length > 0) then
    first:MalValue = ast.list[0]
    fn:MalValue = EVAL(first, env)

    if (fn.type == $MAL_ERROR_TYPE) then
      result = fn
    else
      args:MalValue = MalMkValue($MAL_LIST_TYPE)
      argIndex:i = 1
      argError:i = 0

      while (argIndex < ast.length && argError == 0) do
        argValue:MalValue = ast.list[argIndex]
        argEvaluated:MalValue = EVAL(argValue, env)

        if (argEvaluated.type == $MAL_ERROR_TYPE) then
          args = argEvaluated
          argError = 1
        else
          args = MalAppendValue(args, argEvaluated)
        endif

        argIndex += 1
      od

      if (args.type == $MAL_ERROR_TYPE) then
        result = args
      else
        result = MalApply(fn, args)
      endif
    endif
  endif

  xout result
endop
