;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalEnvHandle(id:i):MalEnv
  env:MalEnv init malEmptyStrings, malEmptyValues, malEmptyEnvs, 0, id, 0
  xout env
endop

opcode MalNextToken(reader:MalReader):MalReader
  position:i = reader.position
  done:i = reader.done
  peek:S init reader.peek

  if (reader.position + 1 >= reader.length) ithen
    done = 1
  else
    position += 1
    peek init malReaderTokens[position]
  endif

  result:MalReader init peek, position, reader.length, done
  xout result
endop

opcode MalAppendValue(destination:MalValue, value:MalValue):MalValue
  capacity:i = lenarray(destination.list)
  resultList:MalValue[] init destination.list

  if (destination.length >= capacity) ithen
    newCapacity:i = capacity > 0 ? capacity * 2 : 1
    values:MalValue[] init newCapacity

    if (destination.length > 0) ithen
      for index in [0 ... destination.length - 1] do
        values[index] init destination.list[index]
      od
    endif

    resultList init values
  endif

  resultList[destination.length] init value
  result:MalValue init destination.type, destination.number, \
    destination.string, resultList, destination.env, destination.metadata, \
    destination.length + 1, destination.isMacro, destination.astRef
  xout result
endop

opcode MalMkReader(tstruct:MalTokens):MalReader
  malReaderTokens init tstruct.length

  if (tstruct.length > 0) ithen
    for index in [0 ... tstruct.length - 1] do
      malReaderTokens[index] init tstruct.tokens[index]
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
  if (value.astRef == 1) ithen
    result:MalValue init malAstNodes[value.number].list[index]
  else
    result:MalValue init value.list[index]
  endif

  xout result
endop

opcode MalAstEnsureCapacity():void
  capacity:i = lenarray(malAstNodes)

  if (malAstNodeCount >= capacity) ithen
    preserved:MalValue[] init malAstNodeCount

    if (malAstNodeCount > 0) ithen
      for index in [0 ... malAstNodeCount - 1] do
        preserved[index] init malAstNodes[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 1024 : capacity * 2
    malAstNodes init newCapacity

    if (malAstNodeCount > 0) ithen
      for index in [0 ... malAstNodeCount - 1] do
        malAstNodes[index] init preserved[index]
      od
    endif
  endif
endop

opcode MalInternAst(value:MalValue):MalValue
  isCollection:i = value.type == $MAL_LIST_TYPE || \
    value.type == $MAL_VECTOR_TYPE || value.type == $MAL_HASH_MAP_TYPE

  if (isCollection == 0 || value.astRef == 1) ithen
    result:MalValue init value
  else
    node:MalValue init value.type, 0, "", malEmptyValues, malEmptyEnvs, \
      value.metadata, 0, 0, 0

    if (value.length > 0) ithen
      for index in [0 ... value.length - 1] do
        child:MalValue MalInternAst value.list[index]
        node MalAppendValue node, child
      od
    endif

    MalAstEnsureCapacity()
    nodeId:i = malAstNodeCount
    malAstNodeCount += 1
    malAstNodes[nodeId] init node

    result:MalValue init value.type, nodeId, "", malEmptyValues, \
      malEmptyEnvs, value.metadata, value.length, 0, 1
  endif

  xout result
endop

opcode MalMkNumber(number:i):MalValue
  value:MalValue init $MAL_NUMBER_TYPE, number, "", malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout value
endop

opcode MalMeta(value:MalValue):MalValue
  if (lenarray(value.metadata) == 0) ithen
    result:MalValue MalMkValue $MAL_NIL_TYPE
  else
    result:MalValue init value.metadata[0]
  endif

  xout result
endop

opcode MalWithMeta(value:MalValue, metadataValue:MalValue):MalValue
  metadata:MalValue[] init 1
  metadata[0] init metadataValue

  result:MalValue init value.type, value.number, value.string, value.list, \
    value.env, metadata, value.length, value.isMacro, value.astRef
  xout result
endop

opcode MalMkSymbol(name:S):MalValue
  val:MalValue init $MAL_SYMBOL_TYPE, 0, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalMkString(value:S):MalValue
  val:MalValue init $MAL_STRING_TYPE, 0, value, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalStringArrayToList(values:S[], startIndex:i):MalValue
  result:MalValue MalMkValue $MAL_LIST_TYPE
  valueCount:i = lenarray(values)
  start:i = startIndex < 0 ? 0 : startIndex

  if (start < valueCount) ithen
    for index in [start ... valueCount - 1] do
      value:S init values[index]
      result MalAppendValue result, MalMkString(value)
    od
  endif

  xout result
endop

opcode MalMkKeyword(name:S):MalValue
  val:MalValue init $MAL_KEYWORD_TYPE, 0, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalMapKeysEqual(left:MalValue, right:MalValue):i
  result:i = 0

  if (left.type == right.type) ithen
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

  if (entryCount > 0) ithen
    for entryIndex in [0 ... entryCount - 1] do
      keyIndex:i = entryIndex * 2

      if (MalMapKeysEqual(MalAt(mapValue, keyIndex), key) == 1) ithen
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

  if (mapValue.length > 0) ithen
    for index in [0 ... mapValue.length - 1] do
      entries[index] MalAt mapValue, index
    od
  endif

  if (keyIndex < 0) ithen
    entries[mapValue.length] init key
    entries[mapValue.length + 1] init value
  else
    entries[keyIndex + 1] init value
  endif

  result:MalValue init $MAL_HASH_MAP_TYPE, 0, "", entries, \
    malEmptyEnvs, malEmptyValues, newLength, 0, 0
  xout result
endop

opcode MalMapDissoc(mapValue:MalValue, key:MalValue):MalValue
  keyIndex:i = MalMapFindKey(mapValue, key)

  if (keyIndex < 0) ithen
    result:MalValue init mapValue
  else
    newLength:i = mapValue.length - 2
    entries:MalValue[] init newLength
    destination:i = 0

    if (mapValue.length > 2) ithen
      for index in [0 ... mapValue.length - 1] do
        if (index != keyIndex && index != keyIndex + 1) ithen
          entries[destination] MalAt mapValue, index
          destination += 1
        endif
      od
    endif

    result:MalValue init $MAL_HASH_MAP_TYPE, 0, "", entries, \
      malEmptyEnvs, malEmptyValues, newLength, 0, 0
  endif

  xout result
endop

opcode MalMapGet(mapValue:MalValue, key:MalValue):MalValue
  keyIndex:i = MalMapFindKey(mapValue, key)

  if (keyIndex < 0) ithen
    result:MalValue MalMkValue $MAL_NIL_TYPE
  else
    result:MalValue MalAt mapValue, keyIndex + 1
  endif

  xout result
endop

opcode MalMapKeys(mapValue:MalValue):MalValue
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) ithen
    for index in [0 ... entryCount - 1] do
      values[index] MalAt mapValue, index * 2
    od
  endif

  result:MalValue init $MAL_LIST_TYPE, 0, "", values, malEmptyEnvs, \
    malEmptyValues, entryCount, 0, 0
  xout result
endop

opcode MalMapValues(mapValue:MalValue):MalValue
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) ithen
    for index in [0 ... entryCount - 1] do
      values[index] MalAt mapValue, index * 2 + 1
    od
  endif

  result:MalValue init $MAL_LIST_TYPE, 0, "", values, malEmptyEnvs, \
    malEmptyValues, entryCount, 0, 0
  xout result
endop

opcode MalNormalizeMap(mapValue:MalValue):MalValue
  result:MalValue MalMkValue $MAL_HASH_MAP_TYPE

  if (mapValue.length > 0) ithen
    for index in [0 ... int(mapValue.length / 2) - 1] do
      keyIndex:i = index * 2
      result MalMapAssoc result, MalAt(mapValue, keyIndex), \
        MalAt(mapValue, keyIndex + 1)
    od
  endif

  xout result
endop

opcode MalMkAtom(value:MalValue):MalValue
  capacity:i = lenarray(malAtomValues)

  if (malAtomCount >= capacity) ithen
    preserved:MalValue[] init capacity

    if (malAtomCount > 0) ithen
      for index in [0 ... malAtomCount - 1] do
        preserved[index] init malAtomValues[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 8 : capacity * 2
    malAtomValues init newCapacity

    if (malAtomCount > 0) ithen
      for index in [0 ... malAtomCount - 1] do
        malAtomValues[index] init preserved[index]
      od
    endif
  endif

  atomId:i = malAtomCount
  malAtomCount += 1
  malAtomValues[atomId] init value

  val:MalValue init $MAL_ATOM_TYPE, atomId, "", malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalAtomValue(atom:MalValue):MalValue
  xout malAtomValues[atom.number]
endop

opcode MalAtomSetValue(atom:MalValue, value:MalValue):MalValue
  malAtomValues[atom.number] init value
  xout value
endop

opcode MalMkBuiltin(name:S):MalValue
  val:MalValue init $MAL_BUILTIN_TYPE, 0, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalMkBuiltinOperator(name:S):MalValue
  val:MalValue init $MAL_BUILTIN_OPERATOR_TYPE, 0, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalMkBuiltinOpcode(name:S):MalValue
  val:MalValue init $MAL_BUILTIN_OPCODE_TYPE, 0, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout val
endop

opcode MalFunctionEnsureCapacity():void
  capacity:i = lenarray(malFunctionDefinitions)

  if (malFunctionCount >= capacity) ithen
    preserved:MalValue[] init malFunctionCount

    if (malFunctionCount > 0) ithen
      for index in [0 ... malFunctionCount - 1] do
        preserved[index] init malFunctionDefinitions[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 256 : capacity * 2
    malFunctionDefinitions init newCapacity

    if (malFunctionCount > 0) ithen
      for index in [0 ... malFunctionCount - 1] do
        malFunctionDefinitions[index] init preserved[index]
      od
    endif
  endif
endop

opcode MalMkFunction(params:MalValue, body:MalValue):MalValue
  MalFunctionEnsureCapacity()

  definition:MalValue MalMkValue $MAL_FUNCTION_TYPE
  definition MalAppendValue definition, params
  definition MalAppendValue definition, MalInternAst(body)

  functionId:i = malFunctionCount
  malFunctionCount += 1
  malFunctionDefinitions[functionId] init definition

  handle:MalValue init $MAL_FUNCTION_TYPE, functionId, "", \
    malEmptyValues, malEmptyEnvs, malEmptyValues, 2, 0, 0
  xout handle
endop

opcode MalFunctionParams(fn:MalValue):MalValue
  xout malFunctionDefinitions[fn.number].list[0]
endop

opcode MalFunctionBody(fn:MalValue):MalValue
  xout malFunctionDefinitions[fn.number].list[1]
endop

opcode MalMkFunctionWithEnv(params:MalValue, body:MalValue, closure:MalEnv[]):MalValue
  val:MalValue MalMkFunction params, body

  if (lenarray(closure) > 0) ithen
    reference:MalEnv[] init 1
    closureId:i init closure[0].id
    reference[0] MalEnvHandle closureId
    result:MalValue init val.type, val.number, val.string, val.list, \
      reference, val.metadata, val.length, val.isMacro, val.astRef
  else
    result:MalValue init val
  endif

  xout result
endop

opcode MalFunctionAsMacro(fn:MalValue):MalValue
  isMacro:i = fn.type == $MAL_FUNCTION_TYPE ? 1 : fn.isMacro
  result:MalValue init fn.type, fn.number, fn.string, fn.list, fn.env, \
    fn.metadata, fn.length, isMacro, fn.astRef

  xout result
endop

opcode MalIsMacro(fn:MalValue):i
  result:i = fn.type == $MAL_FUNCTION_TYPE && fn.isMacro == 1
  xout result
endop

opcode MalMkList1(first:MalValue):MalValue
  val:MalValue MalMkValue $MAL_LIST_TYPE
  val MalAppendValue val, first
  xout val
endop

opcode MalMkList2(first:MalValue, second:MalValue):MalValue
  val:MalValue MalMkValue $MAL_LIST_TYPE
  val MalAppendValue val, first
  val MalAppendValue val, second
  xout val
endop

opcode MalMkList3(first:MalValue, second:MalValue, third:MalValue):MalValue
  val:MalValue MalMkValue $MAL_LIST_TYPE
  val MalAppendValue val, first
  val MalAppendValue val, second
  val MalAppendValue val, third
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

  if (itokenLen > 0 && strchar:i(token, 0) == $MAL_MINUS_TOKEN) ithen
    indx = 1
  endif

  if (indx < itokenLen) ithen
    for indx in [indx ... itokenLen - 1] do
      ichar = strchar:i(token, indx)

      if (ichar >= 48 && ichar < 58) ithen
        idigitCount += 1
      elseif (ichar == $MAL_PERIOD_TOKEN && \
              iperiodCount == 0 && idigitCount > 0) ithen
        iperiodCount = 1
      else
        iinvalid = 1
        break
      endif
    od
  endif

  if (idigitCount > 0 && iinvalid == 0) ithen
    ires = 1
  endif

  xout ires
endop
