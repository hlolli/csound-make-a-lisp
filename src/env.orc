opcode MalMkEnv():MalEnv
  ;; TODO: Once Csound supports zero-argument struct init for UDTs, this
  ;; constructor can become a cleaner default-initialized MalEnv.
  keys:S[] init 0
  values:MalValue[] init 0
  outer:MalEnv[] init 0
  env:MalEnv init keys, values, outer, 0
  xout env
endop

opcode MalMkEnvWithOuter(parent:MalEnv):MalEnv
  keys:S[] init 0
  values:MalValue[] init 0
  outer:MalEnv[] init 1
  outer[0] = parent
  env:MalEnv init keys, values, outer, 0
  xout env
endop

opcode MalEnvFind(env:MalEnv, key:S):i
  indx = 0
  ifound = -1

  if (env.length > 0) then
    for indx in [0 ... env.length - 1] do
      if (strcmp(env.keys[indx], key) == 0) then
        ifound = indx
        break
      endif
    od
  endif

  xout ifound
endop

opcode MalEnvSet(env:MalEnv, key:S, value:MalValue):MalEnv
  index = MalEnvFind(env, key)

  if (index >= 0) then
    env.values[index] = value
  else
    newLength:i = env.length + 1
    keys:S[] init newLength
    values:MalValue[] init newLength

    if (env.length > 0) then
      for indx in [0 ... env.length - 1] do
        keys[indx] = env.keys[indx]
        values[indx] = env.values[indx]
      od
    endif

    keys[env.length] = key
    values[env.length] = value
    env.keys = keys
    env.values = values
    env.length = newLength
  endif

  xout env
endop

opcode MalEnvHas(env:MalEnv, key:S):i
  index = MalEnvFind(env, key)
  result:i = 0

  if (index >= 0) then
    result = 1
  elseif (lenarray(env.outer) > 0) then
    result = MalEnvHas(env.outer[0], key)
  endif

  xout result
endop

opcode MalEnvGet(env:MalEnv, key:S):MalValue
  index = MalEnvFind(env, key)

  if (index >= 0) then
    value:MalValue = env.values[index]
  elseif (lenarray(env.outer) > 0) then
    value:MalValue = MalEnvGet(env.outer[0], key)
  else
    value:MalValue = MalMkError(sprintf("'%s' not found", key))
  endif

  xout value
endop

opcode MalEnvRoot(env:MalEnv):MalEnv
  if (lenarray(env.outer) > 0) then
    root:MalEnv = MalEnvRoot(env.outer[0])
  else
    root:MalEnv = env
  endif

  xout root
endop

opcode MalEnvSetRoot(env:MalEnv, root:MalEnv):MalEnv
  if (lenarray(env.outer) > 0) then
    env.outer[0] = MalEnvSetRoot(env.outer[0], root)
  else
    env = root
  endif

  xout env
endop

opcode MalMkStep2Env():MalEnv
  env:MalEnv = MalMkEnv()
  env = MalEnvSet(env, "+", MalMkBuiltinOperator("+"))
  env = MalEnvSet(env, "-", MalMkBuiltinOperator("-"))
  env = MalEnvSet(env, "*", MalMkBuiltinOperator("*"))
  env = MalEnvSet(env, "/", MalMkBuiltinOperator("/"))
  env = MalEnvSet(env, "list", MalMkBuiltin("list"))
  env = MalEnvSet(env, "cons", MalMkBuiltin("cons"))
  env = MalEnvSet(env, "concat", MalMkBuiltin("concat"))
  env = MalEnvSet(env, "vec", MalMkBuiltin("vec"))
  env = MalEnvSet(env, "nth", MalMkBuiltin("nth"))
  env = MalEnvSet(env, "first", MalMkBuiltin("first"))
  env = MalEnvSet(env, "rest", MalMkBuiltin("rest"))
  env = MalEnvSet(env, "list?", MalMkBuiltin("list?"))
  env = MalEnvSet(env, "empty?", MalMkBuiltin("empty?"))
  env = MalEnvSet(env, "count", MalMkBuiltin("count"))
  env = MalEnvSet(env, "str", MalMkBuiltin("str"))
  env = MalEnvSet(env, "read-string", MalMkBuiltin("read-string"))
  env = MalEnvSet(env, "slurp", MalMkBuiltin("slurp"))
  env = MalEnvSet(env, "eval", MalMkBuiltin("eval"))
  env = MalEnvSet(env, "atom", MalMkBuiltin("atom"))
  env = MalEnvSet(env, "atom?", MalMkBuiltin("atom?"))
  env = MalEnvSet(env, "deref", MalMkBuiltin("deref"))
  env = MalEnvSet(env, "reset!", MalMkBuiltin("reset!"))
  env = MalEnvSet(env, "swap!", MalMkBuiltin("swap!"))
  env = MalEnvSet(env, "=", MalMkBuiltin("="))
  env = MalEnvSet(env, ">", MalMkBuiltin(">"))
  env = MalEnvSet(env, ">=", MalMkBuiltin(">="))
  env = MalEnvSet(env, "<", MalMkBuiltin("<"))
  env = MalEnvSet(env, "<=", MalMkBuiltin("<="))
  env = MalEnvSet(env, "not", MalMkBuiltin("not"))
  env = MalEnvSet(env, "macro?", MalMkBuiltin("macro?"))
  env = MalEnvSet(env, "prn", MalMkBuiltin("prn"))
  xout env
endop
