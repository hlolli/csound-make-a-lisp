opcode MalEnvHandle(id:i):MalEnv
  env:MalEnv init malEmptyStrings, malEmptyValues, malEmptyEnvs, 0, id, 0
  xout env
endop

opcode MalNextToken(reader:MalReader):MalReader
  if (reader.position + 1 >= reader.length) then
    reader.done = 1
  else
    reader.position += 1
    reader.peek = malReaderTokens[reader.position]
  endif
  xout(reader)
endop

opcode MalAppendValue(destination:MalValue, value:MalValue):MalValue
  capacity:i = lenarray(destination.list)

  if (destination.length >= capacity) then
    newCapacity:i = capacity > 0 ? capacity * 2 : 1
    values:MalValue[] init newCapacity

    if (destination.length > 0) then
      for index in [0 ... destination.length - 1] do
        values[index] = destination.list[index]
      od
    endif

    destination.list = values
  endif

  destination.list[destination.length] = value
  destination.length += 1
  xout destination
endop

opcode MalMkReader(tstruct:MalTokens):MalReader
  malReaderTokens init tstruct.length

  if (tstruct.length > 0) then
    for index in [0 ... tstruct.length - 1] do
      malReaderTokens[index] = tstruct.tokens[index]
    od
  endif

  reader:MalReader init malReaderTokens[0], 0, tstruct.length, 0
  xout(reader)
endop

opcode MalMkValue(type:i):MalValue
  val:MalValue init type, 0, "", malEmptyValues, malEmptyEnvs, \
    malEmptyValues, 0, 0, 0
  xout(val)
endop

opcode MalAt(value:MalValue, index:i):MalValue
  if (value.astRef == 1) then
    result:MalValue = malAstNodes[value.number].list[index]
  else
    result:MalValue = value.list[index]
  endif

  xout result
endop

opcode MalAstEnsureCapacity():void
  capacity:i = lenarray(malAstNodes)

  if (malAstNodeCount >= capacity) then
    preserved:MalValue[] init malAstNodeCount

    if (malAstNodeCount > 0) then
      for index in [0 ... malAstNodeCount - 1] do
        preserved[index] = malAstNodes[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 1024 : capacity * 2
    malAstNodes init newCapacity

    if (malAstNodeCount > 0) then
      for index in [0 ... malAstNodeCount - 1] do
        malAstNodes[index] = preserved[index]
      od
    endif
  endif
endop

opcode MalInternAst(value:MalValue):MalValue
  isCollection:i = value.type == $MAL_LIST_TYPE || \
    value.type == $MAL_VECTOR_TYPE || value.type == $MAL_HASH_MAP_TYPE

  if (isCollection == 0 || value.astRef == 1) then
    result:MalValue = value
  else
    node:MalValue = MalMkValue(value.type)
    node.metadata = value.metadata

    if (value.length > 0) then
      for index in [0 ... value.length - 1] do
        child:MalValue = MalInternAst(value.list[index])
        node = MalAppendValue(node, child)
      od
    endif

    MalAstEnsureCapacity()
    nodeId:i = malAstNodeCount
    malAstNodeCount += 1
    malAstNodes[nodeId] = node

    result = MalMkValue(value.type)
    result.number = nodeId
    result.metadata = value.metadata
    result.length = value.length
    result.astRef = 1
  endif

  xout result
endop

opcode MalMaterialize(value:MalValue):MalValue
  isCollection:i = value.type == $MAL_LIST_TYPE || \
    value.type == $MAL_VECTOR_TYPE || value.type == $MAL_HASH_MAP_TYPE

  if (isCollection == 0) then
    result:MalValue = value
  else
    result = MalMkValue(value.type)
    result.metadata = value.metadata

    if (value.length > 0) then
      for index in [0 ... value.length - 1] do
        child:MalValue = MalMaterialize(MalAt(value, index))
        result = MalAppendValue(result, child)
      od
    endif
  endif

  xout result
endop

opcode MalMkNumber(number:i):MalValue
  value:MalValue = MalMkValue($MAL_NUMBER_TYPE)
  value.number = number
  xout value
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

opcode MalStringArrayToList(values:S[], startIndex:i):MalValue
  result:MalValue = MalMkValue($MAL_LIST_TYPE)
  valueCount:i = lenarray(values)
  start:i = startIndex < 0 ? 0 : startIndex

  if (start < valueCount) then
    for index in [start ... valueCount - 1] do
      value:S = values[index]
      result = MalAppendValue(result, MalMkString(value))
    od
  endif

  xout result
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

      if (MalMapKeysEqual(MalAt(mapValue, keyIndex), key) == 1) then
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
      entries[index] = MalAt(mapValue, index)
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
          entries[destination] = MalAt(mapValue, index)
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
    result:MalValue = MalAt(mapValue, keyIndex + 1)
  endif

  xout result
endop

opcode MalMapKeys(mapValue:MalValue):MalValue
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) then
    for index in [0 ... entryCount - 1] do
      values[index] = MalAt(mapValue, index * 2)
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
      values[index] = MalAt(mapValue, index * 2 + 1)
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
        result, MalAt(mapValue, keyIndex), MalAt(mapValue, keyIndex + 1))
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

opcode MalFunctionEnsureCapacity():void
  capacity:i = lenarray(malFunctionDefinitions)

  if (malFunctionCount >= capacity) then
    preserved:MalValue[] init malFunctionCount

    if (malFunctionCount > 0) then
      for index in [0 ... malFunctionCount - 1] do
        preserved[index] = malFunctionDefinitions[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 256 : capacity * 2
    malFunctionDefinitions init newCapacity

    if (malFunctionCount > 0) then
      for index in [0 ... malFunctionCount - 1] do
        malFunctionDefinitions[index] = preserved[index]
      od
    endif
  endif
endop

opcode MalMkFunction(params:MalValue, body:MalValue):MalValue
  MalFunctionEnsureCapacity()

  definition:MalValue = MalMkValue($MAL_FUNCTION_TYPE)
  definition = MalAppendValue(definition, params)
  definition = MalAppendValue(definition, MalInternAst(body))

  functionId:i = malFunctionCount
  malFunctionCount += 1
  malFunctionDefinitions[functionId] = definition

  handle:MalValue = MalMkValue($MAL_FUNCTION_TYPE)
  handle.number = functionId
  handle.length = 2
  xout handle
endop

opcode MalFunctionParams(fn:MalValue):MalValue
  xout malFunctionDefinitions[fn.number].list[0]
endop

opcode MalFunctionBody(fn:MalValue):MalValue
  xout malFunctionDefinitions[fn.number].list[1]
endop

opcode MalMkFunctionWithEnv(params:MalValue, body:MalValue, closure:MalEnv[]):MalValue
  val:MalValue = MalMkFunction(params, body)

  if (lenarray(closure) > 0) then
    reference:MalEnv[] init 1
    reference[0] = MalEnvHandle(closure[0].id)
    val.env = reference
  endif

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
  result:MalReadResult init value, reader
  xout result
endop

opcode MalReadResultValue(result:MalReadResult):MalValue
  xout result.value
endop

opcode MalReadResultReader(result:MalReadResult):MalReader
  xout result.reader
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
