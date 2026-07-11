malEnvRegistry@global:MalEnv[] init 0
malEnvCount@global:i init 0
malEnvFreeIds@global:i[] init 0
malEnvFreeCount@global:i init 0

opcode MalEnvEnsureCapacity():void
  capacity:i = lenarray(malEnvRegistry)

  if (malEnvCount >= capacity) then
    preserved:MalEnv[] init malEnvCount

    if (malEnvCount > 0) then
      for index in [0 ... malEnvCount - 1] do
        preserved[index] = malEnvRegistry[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 256 : capacity * 2
    malEnvRegistry init newCapacity

    if (malEnvCount > 0) then
      for index in [0 ... malEnvCount - 1] do
        malEnvRegistry[index] = preserved[index]
      od
    endif
  endif
endop

opcode MalEnvPushFreeId(id:i):void
  capacity:i = lenarray(malEnvFreeIds)

  if (malEnvFreeCount >= capacity) then
    preserved:i[] init malEnvFreeCount

    if (malEnvFreeCount > 0) then
      for index in [0 ... malEnvFreeCount - 1] do
        preserved[index] = malEnvFreeIds[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 64 : capacity * 2
    malEnvFreeIds init newCapacity

    if (malEnvFreeCount > 0) then
      for index in [0 ... malEnvFreeCount - 1] do
        malEnvFreeIds[index] = preserved[index]
      od
    endif
  endif

  malEnvFreeIds[malEnvFreeCount] = id
  malEnvFreeCount += 1
endop

opcode MalEnvAllocateId():i
  id:i = -1

  if (malEnvFreeCount > 0) then
    malEnvFreeCount -= 1
    id = malEnvFreeIds[malEnvFreeCount]
  else
    MalEnvEnsureCapacity()
    id = malEnvCount
    malEnvCount += 1
  endif

  xout id
endop

opcode MalEnvResolve(env:MalEnv):MalEnv
  if (env.id >= 0 && env.id < malEnvCount) then
    stored:MalEnv = malEnvRegistry[env.id]

    if (stored.id == env.id) then
      result:MalEnv = stored
    else
      result:MalEnv = env
    endif
  else
    result:MalEnv = env
  endif

  xout result
endop

opcode MalEnvStore(env:MalEnv):MalEnv
  if (env.id >= 0 && env.id < malEnvCount) then
    malEnvRegistry[env.id] = env
  endif

  xout env
endop

opcode MalEnvRetain(env:MalEnv):MalEnv
  resolved:MalEnv = MalEnvResolve(env)

  if (resolved.id >= 0 && resolved.persistent == 0) then
    resolved.persistent = 1
    resolved = MalEnvStore(resolved)

    if (lenarray(resolved.outer) > 0) then
      outer:MalEnv = MalEnvRetain(resolved.outer[0])
      resolved.outer[0] = MalEnvHandle(outer.id)
      resolved = MalEnvStore(resolved)
    endif
  endif

  xout resolved
endop

opcode MalEnvRelease(env:MalEnv):void
  resolved:MalEnv = MalEnvResolve(env)

  if (resolved.id > 0 && resolved.persistent == 0 && \
      malEnvRegistry[resolved.id].id == resolved.id) then
    releasedId:i = resolved.id
    malEnvRegistry[releasedId] = MalEnvHandle(-1)
    MalEnvPushFreeId(releasedId)
  endif
endop

opcode MalMkEnv():MalEnv
  ;; TODO: Once Csound supports zero-argument struct init for UDTs, this
  ;; constructor can become a cleaner default-initialized MalEnv.
  id:i = MalEnvAllocateId()
  env:MalEnv init malEmptyStrings, malEmptyValues, malEmptyEnvs, 0, id, 1
  env = MalEnvStore(env)
  xout env
endop

opcode MalMkEnvWithOuter(parent:MalEnv):MalEnv
  id:i = MalEnvAllocateId()
  resolvedParent:MalEnv = MalEnvResolve(parent)
  outer:MalEnv[] init 1
  outer[0] = MalEnvHandle(resolvedParent.id)
  env:MalEnv init malEmptyStrings, malEmptyValues, outer, 0, id, 0
  env = MalEnvStore(env)
  xout env
endop

opcode MalEnvFind(env:MalEnv, key:S):i
  resolved:MalEnv = MalEnvResolve(env)
  found:i = -1

  if (resolved.length > 0) then
    for index in [0 ... resolved.length - 1] do
      if (strcmp(resolved.keys[index], key) == 0) then
        found = index
        break
      endif
    od
  endif

  xout found
endop

opcode MalEnvSet(env:MalEnv, key:S, value:MalValue):MalEnv
  resolved:MalEnv = MalEnvResolve(env)
  index:i = MalEnvFind(resolved, key)

  if (index >= 0) then
    resolved.values[index] = value
  else
    newLength:i = resolved.length + 1
    keys:S[] init newLength
    values:MalValue[] init newLength

    if (resolved.length > 0) then
      for itemIndex in [0 ... resolved.length - 1] do
        keys[itemIndex] = resolved.keys[itemIndex]
        values[itemIndex] = resolved.values[itemIndex]
      od
    endif

    keys[resolved.length] = key
    values[resolved.length] = value
    resolved.keys = keys
    resolved.values = values
    resolved.length = newLength
  endif

  resolved = MalEnvStore(resolved)
  xout resolved
endop

opcode MalEnvHas(env:MalEnv, key:S):i
  resolved:MalEnv = MalEnvResolve(env)
  index:i = MalEnvFind(resolved, key)
  result:i = 0

  if (index >= 0) then
    result = 1
  elseif (lenarray(resolved.outer) > 0) then
    result = MalEnvHas(resolved.outer[0], key)
  endif

  xout result
endop

opcode MalEnvGet(env:MalEnv, key:S):MalValue
  resolved:MalEnv = MalEnvResolve(env)
  index:i = MalEnvFind(resolved, key)

  if (index >= 0) then
    value:MalValue = resolved.values[index]
  elseif (lenarray(resolved.outer) > 0) then
    value:MalValue = MalEnvGet(resolved.outer[0], key)
  else
    value:MalValue = MalMkError(sprintf("'%s' not found", key))
  endif

  xout value
endop

opcode MalEnvRoot(env:MalEnv):MalEnv
  resolved:MalEnv = MalEnvResolve(env)

  if (lenarray(resolved.outer) > 0) then
    root:MalEnv = MalEnvRoot(resolved.outer[0])
  else
    root:MalEnv = resolved
  endif

  xout root
endop

opcode MalEnvSetRoot(env:MalEnv, root:MalEnv):MalEnv
  resolved:MalEnv = MalEnvResolve(env)

  if (lenarray(resolved.outer) > 0) then
    updatedOuter:MalEnv = MalEnvSetRoot(resolved.outer[0], root)
    resolved.outer[0] = MalEnvHandle(updatedOuter.id)
    result:MalEnv = MalEnvStore(resolved)
  else
    result:MalEnv = MalEnvResolve(root)
  endif

  xout result
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
