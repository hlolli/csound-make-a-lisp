declare EVAL(result:MalValue):(MalValue, MalEnv)

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

opcode MalEvalSequence(ast:MalValue, env:MalEnv, startIndex:i, resultType:i):MalValue
  result:MalValue = MalMkValue(resultType)
  index:i = startIndex
  done:i = 0

  while (index < ast.length && done == 0) do
    value:MalValue = ast.list[index]
    evaluated:MalValue = EVAL(value, env)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated
      done = 1
    else
      result = MalAppendValue(result, evaluated)
    endif

    index += 1
  od

  xout result
endop

opcode MalEvalHashMap(ast:MalValue, env:MalEnv):MalValue
  result:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)
  index:i = 0
  done:i = 0

  while (index < ast.length && done == 0) do
    key:MalValue = ast.list[index]
    value:MalValue = ast.list[index + 1]
    evaluated:MalValue = EVAL(value, env)

    if (evaluated.type == $MAL_ERROR_TYPE) then
      result = evaluated
      done = 1
    else
      result = MalAppendValue(result, key)
      result = MalAppendValue(result, evaluated)
    endif

    index += 2
  od

  xout result
endop

opcode MalEvalAst(ast:MalValue, env:MalEnv):MalValue
  result:MalValue = ast

  if (ast.type == $MAL_SYMBOL_TYPE) then
    result = MalEnvGet(env, ast.string)
  elseif (ast.type == $MAL_LIST_TYPE) then
    result = MalEvalSequence(ast, env, 0, $MAL_LIST_TYPE)
  elseif (ast.type == $MAL_VECTOR_TYPE) then
    result = MalEvalSequence(ast, env, 0, $MAL_VECTOR_TYPE)
  elseif (ast.type == $MAL_HASH_MAP_TYPE) then
    result = MalEvalHashMap(ast, env)
  endif

  xout result
endop

opcode EVAL(ast:MalValue, env:MalEnv):MalValue
  result:MalValue = ast

  if (ast.type == $MAL_LIST_TYPE && ast.length > 0) then
    evaluatedList:MalValue = MalEvalAst(ast, env)

    if (evaluatedList.type == $MAL_ERROR_TYPE) then
      result = evaluatedList
    else
      fn:MalValue = evaluatedList.list[0]
      args:MalValue = MalMkValue($MAL_LIST_TYPE)
      argIndex:i = 1

      while (argIndex < evaluatedList.length) do
        args = MalAppendValue(args, evaluatedList.list[argIndex])
        argIndex += 1
      od

      result = MalApply(fn, args)
    endif
  else
    result = MalEvalAst(ast, env)
  endif

  xout result
endop
