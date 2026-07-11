opcode MalNextToken(reader:MalReader):MalReader
  if (reader.position + 1 >= reader.length) then
    reader.done = 1
  else
    reader.position += 1
    STokens[] = reader.tokens
    reader.peek = STokens[reader.position]
  endif
  xout(reader)
endop

opcode MalAppendValue(destination:MalValue, value:MalValue):MalValue
  destination.list[destination.length] = value
  destination.length += 1
  xout destination
endop

opcode MalMkReader(tstruct:MalTokens):MalReader
  Stokens[] slicearray_i tstruct.tokens, 0, tstruct.length
  reader:MalReader init Stokens[0], 0, Stokens, tstruct.length, 0
  xout(reader)
endop

opcode MalMkValue(type:i):MalValue
  list:MalValue[] init 12
  env:MalEnv[] init 0
  metadata:MalValue[] init 0
  val:MalValue init type, 0, "", list, env, metadata, 0, 0
  xout(val)
endop

opcode MalMeta(value:MalValue):MalValue
  if (lenarray(value.metadata) == 0) then
    result:MalValue = MalMkValue($MAL_NIL_TYPE)
  else
    result:MalValue = value.metadata[0]
  endif

  xout result
endop

opcode MalWithMeta(value:MalValue, metadataValue:MalValue):MalValue
  metadata:MalValue[] init 1
  metadata[0] = metadataValue

  result:MalValue = value
  result.metadata = metadata
  xout result
endop

opcode MalMkSymbol(name:S):MalValue
  val:MalValue = MalMkValue($MAL_SYMBOL_TYPE)
  val.string = name
  xout val
endop

opcode MalMkString(value:S):MalValue
  val:MalValue = MalMkValue($MAL_STRING_TYPE)
  val.string = value
  xout val
endop

opcode MalMkKeyword(name:S):MalValue
  val:MalValue = MalMkValue($MAL_KEYWORD_TYPE)
  val.string = name
  xout val
endop

opcode MalMapKeysEqual(left:MalValue, right:MalValue):i
  result:i = 0

  if (left.type == right.type) then
    switch left.type
      case $MAL_STRING_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_KEYWORD_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_SYMBOL_TYPE
        result = strcmp(left.string, right.string) == 0

      case $MAL_NUMBER_TYPE
        result = left.number == right.number

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

opcode MalMapFindKey(mapValue:MalValue, key:MalValue):i
  result:i = -1
  entryCount:i = int(mapValue.length / 2)

  if (entryCount > 0) then
    for entryIndex in [0 ... entryCount - 1] do
      keyIndex:i = entryIndex * 2

      if (MalMapKeysEqual(mapValue.list[keyIndex], key) == 1) then
        result = keyIndex
        break
      endif
    od
  endif

  xout result
endop

opcode MalMapAssoc(mapValue:MalValue, key:MalValue, value:MalValue):MalValue
  keyIndex:i = MalMapFindKey(mapValue, key)
  newLength:i = mapValue.length + (keyIndex < 0 ? 2 : 0)
  entries:MalValue[] init newLength

  if (mapValue.length > 0) then
    for index in [0 ... mapValue.length - 1] do
      entries[index] = mapValue.list[index]
    od
  endif

  if (keyIndex < 0) then
    entries[mapValue.length] = key
    entries[mapValue.length + 1] = value
  else
    entries[keyIndex + 1] = value
  endif

  result:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)
  result.list = entries
  result.length = newLength
  xout result
endop

opcode MalMapDissoc(mapValue:MalValue, key:MalValue):MalValue
  keyIndex:i = MalMapFindKey(mapValue, key)

  if (keyIndex < 0) then
    result:MalValue = mapValue
  else
    newLength:i = mapValue.length - 2
    entries:MalValue[] init newLength
    destination:i = 0

    if (mapValue.length > 2) then
      for index in [0 ... mapValue.length - 1] do
        if (index != keyIndex && index != keyIndex + 1) then
          entries[destination] = mapValue.list[index]
          destination += 1
        endif
      od
    endif

    result:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)
    result.list = entries
    result.length = newLength
  endif

  xout result
endop

opcode MalMapGet(mapValue:MalValue, key:MalValue):MalValue
  keyIndex:i = MalMapFindKey(mapValue, key)

  if (keyIndex < 0) then
    result:MalValue = MalMkValue($MAL_NIL_TYPE)
  else
    result:MalValue = mapValue.list[keyIndex + 1]
  endif

  xout result
endop

opcode MalMapKeys(mapValue:MalValue):MalValue
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) then
    for index in [0 ... entryCount - 1] do
      values[index] = mapValue.list[index * 2]
    od
  endif

  result:MalValue = MalMkValue($MAL_LIST_TYPE)
  result.list = values
  result.length = entryCount
  xout result
endop

opcode MalMapValues(mapValue:MalValue):MalValue
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) then
    for index in [0 ... entryCount - 1] do
      values[index] = mapValue.list[index * 2 + 1]
    od
  endif

  result:MalValue = MalMkValue($MAL_LIST_TYPE)
  result.list = values
  result.length = entryCount
  xout result
endop

opcode MalNormalizeMap(mapValue:MalValue):MalValue
  result:MalValue = MalMkValue($MAL_HASH_MAP_TYPE)

  if (mapValue.length > 0) then
    for index in [0 ... int(mapValue.length / 2) - 1] do
      keyIndex:i = index * 2
      result = MalMapAssoc( \
        result, mapValue.list[keyIndex], mapValue.list[keyIndex + 1])
    od
  endif

  xout result
endop

opcode MalMkAtom(value:MalValue):MalValue
  capacity:i = lenarray(malAtomValues)

  if (malAtomCount >= capacity) then
    preserved:MalValue[] init capacity

    if (malAtomCount > 0) then
      for index in [0 ... malAtomCount - 1] do
        preserved[index] = malAtomValues[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 8 : capacity * 2
    malAtomValues init newCapacity

    if (malAtomCount > 0) then
      for index in [0 ... malAtomCount - 1] do
        malAtomValues[index] = preserved[index]
      od
    endif
  endif

  atomId:i = malAtomCount
  malAtomCount += 1
  malAtomValues[atomId] = value

  val:MalValue = MalMkValue($MAL_ATOM_TYPE)
  val.number = atomId
  xout val
endop

opcode MalAtomValue(atom:MalValue):MalValue
  xout malAtomValues[atom.number]
endop

opcode MalAtomSetValue(atom:MalValue, value:MalValue):MalValue
  malAtomValues[atom.number] = value
  xout value
endop

opcode MalMkBuiltin(name:S):MalValue
  val:MalValue = MalMkValue($MAL_BUILTIN_TYPE)
  val.string = name
  xout val
endop

opcode MalMkBuiltinOperator(name:S):MalValue
  val:MalValue = MalMkValue($MAL_BUILTIN_OPERATOR_TYPE)
  val.string = name
  xout val
endop

opcode MalMkBuiltinOpcode(name:S):MalValue
  val:MalValue = MalMkValue($MAL_BUILTIN_OPCODE_TYPE)
  val.string = name
  xout val
endop

opcode MalMkFunction(params:MalValue, body:MalValue):MalValue
  val:MalValue = MalMkValue($MAL_FUNCTION_TYPE)
  val = MalAppendValue(val, params)
  val = MalAppendValue(val, body)
  xout val
endop

opcode MalMkFunctionWithEnv(params:MalValue, body:MalValue, closure:MalEnv[]):MalValue
  val:MalValue = MalMkFunction(params, body)
  val.env = closure
  xout val
endop

opcode MalFunctionAsMacro(fn:MalValue):MalValue
  result:MalValue = fn

  if (fn.type == $MAL_FUNCTION_TYPE) then
    result.isMacro = 1
  endif

  xout result
endop

opcode MalIsMacro(fn:MalValue):i
  result:i = fn.type == $MAL_FUNCTION_TYPE && fn.isMacro == 1
  xout result
endop

opcode MalMkList1(first:MalValue):MalValue
  val:MalValue = MalMkValue($MAL_LIST_TYPE)
  val = MalAppendValue(val, first)
  xout val
endop

opcode MalMkList2(first:MalValue, second:MalValue):MalValue
  val:MalValue = MalMkValue($MAL_LIST_TYPE)
  val = MalAppendValue(val, first)
  val = MalAppendValue(val, second)
  xout val
endop

opcode MalMkList3(first:MalValue, second:MalValue, third:MalValue):MalValue
  val:MalValue = MalMkValue($MAL_LIST_TYPE)
  val = MalAppendValue(val, first)
  val = MalAppendValue(val, second)
  val = MalAppendValue(val, third)
  xout val
endop

opcode MalMkReadResult(value:MalValue, reader:MalReader):MalReadResult
  result:MalReadResult init value.type, value.number, value.string, value.list, \
    value.env, value.metadata, value.length, value.isMacro, reader.peek, \
    reader.position, reader.tokens, reader.length, reader.done
  xout result
endop

opcode MalReadResultValue(result:MalReadResult):MalValue
  value:MalValue init result.type, result.number, result.string, result.list, \
    result.env, result.metadata, result.length, result.isMacro
  xout value
endop

opcode MalReadResultReader(result:MalReadResult):MalReader
  reader:MalReader init result.readerPeek, result.readerPosition, \
    result.readerTokens, result.readerLength, result.readerDone
  xout reader
endop

opcode MalIsNumericString(token:S):i
  itokenLen = strlen(token)
  ires = 0
  indx = 0
  idigitCount = 0
  iperiodCount = 0
  iinvalid = 0

  if (itokenLen > 0 && strchar:i(token, 0) == $MAL_MINUS_TOKEN) then
    indx = 1
  endif

  if (indx < itokenLen) then
    for indx in [indx ... itokenLen - 1] do
      ichar = strchar:i(token, indx)

      if (ichar >= 48 && ichar < 58) then
        idigitCount += 1
      elseif (ichar == $MAL_PERIOD_TOKEN && \
              iperiodCount == 0 && idigitCount > 0) then
        iperiodCount = 1
      else
        iinvalid = 1
        break
      endif
    od
  endif

  if (idigitCount > 0 && iinvalid == 0) then
    ires = 1
  endif

  xout ires
endop
