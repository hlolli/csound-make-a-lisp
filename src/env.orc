;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

malEnvRegistry@global:MalEnv[] init 0
malEnvCount@global:i init 0
malEnvFreeIds@global:i[] init 0
malEnvFreeCount@global:i init 0

opcode MalEnvEnsureCapacity():void
  capacity:i = lenarray(malEnvRegistry)

  if (malEnvCount >= capacity) ithen
    preserved:MalEnv[] init malEnvCount

    if (malEnvCount > 0) ithen
      for index in [0 ... malEnvCount - 1] do
        preserved[index] init malEnvRegistry[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 256 : capacity * 2
    malEnvRegistry init newCapacity

    if (malEnvCount > 0) ithen
      for index in [0 ... malEnvCount - 1] do
        malEnvRegistry[index] init preserved[index]
      od
    endif
  endif
endop

opcode MalEnvPushFreeId(id:i):void
  capacity:i = lenarray(malEnvFreeIds)

  if (malEnvFreeCount >= capacity) ithen
    preserved:i[] init malEnvFreeCount

    if (malEnvFreeCount > 0) ithen
      for index in [0 ... malEnvFreeCount - 1] do
        preserved[index] = malEnvFreeIds[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 64 : capacity * 2
    malEnvFreeIds init newCapacity

    if (malEnvFreeCount > 0) ithen
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

  if (malEnvFreeCount > 0) ithen
    malEnvFreeCount -= 1
    id = malEnvFreeIds[malEnvFreeCount]
  else
    MalEnvEnsureCapacity()
    id = malEnvCount
    malEnvCount += 1
  endif

  xout id
endop

;; MAL evaluates at init, where Csound can detach shared arrays on writes.
;; The member constructor lets snapshots share the value and outer arrays.
opcode MalEnvSnapshot(env:MalEnv):MalEnv
  result:MalEnv init env.keys, env.values, env.outer, env.length, env.id, \
    env.persistent
  xout result
endop

opcode MalEnvResolve(env:MalEnv):MalEnv
  if (env.id >= 0 && env.id < malEnvCount) ithen
    stored:MalEnv MalEnvSnapshot malEnvRegistry[env.id]

    if (stored.id == env.id) ithen
      result:MalEnv MalEnvSnapshot stored
    else
      result:MalEnv MalEnvSnapshot env
    endif
  else
    result:MalEnv MalEnvSnapshot env
  endif

  xout result
endop

opcode MalEnvStore(env:MalEnv):MalEnv
  if (env.id >= 0 && env.id < malEnvCount) ithen
    malEnvRegistry[env.id] init env
  endif

  xout env
endop

opcode MalEnvRetain(env:MalEnv):MalEnv
  resolved:MalEnv MalEnvResolve env

  if (resolved.id >= 0 && resolved.persistent == 0) ithen
    resolved init resolved.keys, resolved.values, resolved.outer, \
      resolved.length, resolved.id, 1
    resolved MalEnvStore resolved

    if (lenarray(resolved.outer) > 0) ithen
      outer:MalEnv MalEnvRetain resolved.outer[0]
      resolved.outer[0] MalEnvHandle outer.id
      resolved MalEnvStore resolved
    endif
  endif

  xout resolved
endop

opcode MalEnvRelease(env:MalEnv):void
  resolved:MalEnv MalEnvResolve env

  if (resolved.id > 0 && resolved.persistent == 0 && \
      malEnvRegistry[resolved.id].id == resolved.id) ithen
    releasedId:i = resolved.id
    malEnvRegistry[releasedId] MalEnvHandle -1
    MalEnvPushFreeId(releasedId)
  endif
endop

opcode MalMkEnv():MalEnv
  ;; TODO: Once Csound supports zero-argument struct init for UDTs, this
  ;; constructor can become a cleaner default-initialized MalEnv.
  id:i MalEnvAllocateId
  env:MalEnv init malEmptyStrings, malEmptyValues, malEmptyEnvs, 0, id, 1
  env MalEnvStore env
  xout env
endop

opcode MalMkEnvWithOuter(parent:MalEnv):MalEnv
  id:i MalEnvAllocateId
  resolvedParent:MalEnv MalEnvResolve parent
  outer:MalEnv[] init 1
  outer[0] MalEnvHandle resolvedParent.id
  env:MalEnv init malEmptyStrings, malEmptyValues, outer, 0, id, 0
  env MalEnvStore env
  xout env
endop

opcode MalEnvFind(env:MalEnv, key:S):i
  resolved:MalEnv MalEnvResolve env
  found:i = -1

  if (resolved.length > 0) ithen
    for index in [0 ... resolved.length - 1] do
      storedKey:S init resolved.keys[index]
      comparison:i strcmp storedKey, key

      if (comparison == 0) ithen
        found = index
        break
      endif
    od
  endif

  xout found
endop

opcode MalEnvSet(env:MalEnv, key:S, value:MalValue):MalEnv
  resolved:MalEnv MalEnvResolve env
  index:i MalEnvFind resolved, key

  if (index >= 0) ithen
    resolved.values[index] init value
  else
    newLength:i = resolved.length + 1
    keys:S[] init newLength
    values:MalValue[] init newLength

    if (resolved.length > 0) ithen
      for itemIndex in [0 ... resolved.length - 1] do
        keys[itemIndex] init resolved.keys[itemIndex]
        values[itemIndex] init resolved.values[itemIndex]
      od
    endif

    keys[resolved.length] init key
    values[resolved.length] init value
    resolved init keys, values, resolved.outer, newLength, resolved.id, \
      resolved.persistent
  endif

  resolved MalEnvStore resolved
  xout resolved
endop

opcode MalEnvHas(env:MalEnv, key:S):i
  resolved:MalEnv MalEnvResolve env
  index:i MalEnvFind resolved, key
  result:i = 0

  if (index >= 0) ithen
    result = 1
  elseif (lenarray(resolved.outer) > 0) ithen
    result MalEnvHas resolved.outer[0], key
  endif

  xout result
endop

opcode MalEnvGet(env:MalEnv, key:S):MalValue
  resolved:MalEnv MalEnvResolve env
  index:i MalEnvFind resolved, key

  if (index >= 0) ithen
    value:MalValue init resolved.values[index]
  elseif (lenarray(resolved.outer) > 0) ithen
    value:MalValue MalEnvGet resolved.outer[0], key
  else
    value:MalValue MalMkError sprintf("'%s' not found", key)
  endif

  xout value
endop

opcode MalEnvRoot(env:MalEnv):MalEnv
  resolved:MalEnv MalEnvResolve env

  if (lenarray(resolved.outer) > 0) ithen
    root:MalEnv MalEnvRoot resolved.outer[0]
  else
    root:MalEnv init resolved
  endif

  xout root
endop

opcode MalEnvSetRoot(env:MalEnv, root:MalEnv):MalEnv
  resolved:MalEnv MalEnvResolve env

  if (lenarray(resolved.outer) > 0) ithen
    updatedOuter:MalEnv MalEnvSetRoot resolved.outer[0], root
    resolved.outer[0] MalEnvHandle updatedOuter.id
    result:MalEnv MalEnvStore resolved
  else
    result:MalEnv MalEnvResolve root
  endif

  xout result
endop

opcode MalMkStep2Env():MalEnv
  env:MalEnv init MalMkEnv()
  env init MalEnvSet(env, "+", MalMkBuiltinOperator("+"))
  env init MalEnvSet(env, "-", MalMkBuiltinOperator("-"))
  env init MalEnvSet(env, "*", MalMkBuiltinOperator("*"))
  env init MalEnvSet(env, "/", MalMkBuiltinOperator("/"))
  env init MalEnvSet(env, "list", MalMkBuiltin("list"))
  env init MalEnvSet(env, "cons", MalMkBuiltin("cons"))
  env init MalEnvSet(env, "concat", MalMkBuiltin("concat"))
  env init MalEnvSet(env, "vec", MalMkBuiltin("vec"))
  env init MalEnvSet(env, "nth", MalMkBuiltin("nth"))
  env init MalEnvSet(env, "first", MalMkBuiltin("first"))
  env init MalEnvSet(env, "rest", MalMkBuiltin("rest"))
  env init MalEnvSet(env, "list?", MalMkBuiltin("list?"))
  env init MalEnvSet(env, "empty?", MalMkBuiltin("empty?"))
  env init MalEnvSet(env, "count", MalMkBuiltin("count"))
  env init MalEnvSet(env, "str", MalMkBuiltin("str"))
  env init MalEnvSet(env, "read-string", MalMkBuiltin("read-string"))
  env init MalEnvSet(env, "slurp", MalMkBuiltin("slurp"))
  env init MalEnvSet(env, "eval", MalMkBuiltin("eval"))
  env init MalEnvSet(env, "atom", MalMkBuiltin("atom"))
  env init MalEnvSet(env, "atom?", MalMkBuiltin("atom?"))
  env init MalEnvSet(env, "deref", MalMkBuiltin("deref"))
  env init MalEnvSet(env, "reset!", MalMkBuiltin("reset!"))
  env init MalEnvSet(env, "swap!", MalMkBuiltin("swap!"))
  env init MalEnvSet(env, "=", MalMkBuiltin("="))
  env init MalEnvSet(env, ">", MalMkBuiltin(">"))
  env init MalEnvSet(env, ">=", MalMkBuiltin(">="))
  env init MalEnvSet(env, "<", MalMkBuiltin("<"))
  env init MalEnvSet(env, "<=", MalMkBuiltin("<="))
  env init MalEnvSet(env, "not", MalMkBuiltin("not"))
  env init MalEnvSet(env, "macro?", MalMkBuiltin("macro?"))
  env init MalEnvSet(env, "prn", MalMkBuiltin("prn"))
  xout env
endop
