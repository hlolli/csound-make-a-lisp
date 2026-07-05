opcode MalMkEnv():MalEnv
  keys:S[] init 1
  values:MalValue[] init 1
  env:MalEnv init keys, values, 0
  xout env
endop

opcode MalEnvFind(env:MalEnv, key:S):i
  indx = 0
  ifound = -1

  while (indx < env.length && ifound == -1) do
    if (strcmp(env.keys[indx], key) == 0) then
      ifound = indx
    endif
    indx += 1
  od

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

    indx = 0
    while (indx < env.length) do
      keys[indx] = env.keys[indx]
      values[indx] = env.values[indx]
      indx += 1
    od

    keys[env.length] = key
    values[env.length] = value
    env.keys = keys
    env.values = values
    env.length = newLength
  endif

  xout env
endop

opcode MalEnvGet(env:MalEnv, key:S):MalValue
  index = MalEnvFind(env, key)

  if (index >= 0) then
    value:MalValue = env.values[index]
  else
    value:MalValue = MalMkError(sprintf("'%s' not found", key))
  endif

  xout value
endop

opcode MalMkStep2Env():MalEnv
  env:MalEnv = MalMkEnv()
  env = MalEnvSet(env, "+", MalMkBuiltinOperator("+"))
  env = MalEnvSet(env, "-", MalMkBuiltinOperator("-"))
  env = MalEnvSet(env, "*", MalMkBuiltinOperator("*"))
  env = MalEnvSet(env, "/", MalMkBuiltinOperator("/"))
  xout env
endop
