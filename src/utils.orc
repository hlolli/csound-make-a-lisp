;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

declare MalEquals(left:MalValue, right:MalValue):(i)

opcode MalEnvHandle(id:i):MalEnv
  valueType:i = $MAL_LIST_TYPE
  zero:i = 0
  paths:MalValue init valueType, zero, "", malEmptyValues, malEmptyEnvs, malEmptyValues, zero, zero, zero
  env:MalEnv init malEmptyStrings, malEmptyValues, malEmptyEnvs, zero, id, zero, "", paths
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
  zero:i = 0
  malReaderTokens init tstruct.length

  if (tstruct.length > 0) ithen
    for index in [0 ... tstruct.length - 1] do
      malReaderTokens[index] init tstruct.tokens[index]
    od
  endif

  reader:MalReader init malReaderTokens[0], zero, tstruct.length, zero
  xout(reader)
endop

opcode MalMkValue(type:i):MalValue
  zero:i = 0
  val:MalValue init type, zero, "", malEmptyValues, malEmptyEnvs, \
    malEmptyValues, zero, zero, zero
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
  zero:i = 0
  one:i = 1
  isCollection:i = value.type == $MAL_LIST_TYPE || \
    value.type == $MAL_VECTOR_TYPE || value.type == $MAL_HASH_MAP_TYPE

  if (isCollection == 0 || value.astRef == 1) ithen
    result:MalValue init value
  else
    node:MalValue init value.type, zero, "", malEmptyValues, malEmptyEnvs, \
      value.metadata, zero, zero, zero

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
      malEmptyEnvs, value.metadata, value.length, zero, one
  endif

  xout result
endop

opcode MalMkNumber(number:i):MalValue
  valueType:i = $MAL_NUMBER_TYPE
  zero:i = 0
  value:MalValue init valueType, number, "", malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
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
  valueType:i = $MAL_SYMBOL_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalMkString(value:S):MalValue
  valueType:i = $MAL_STRING_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, value, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalStringCharacterEnd(value:S, start:i, length:i):i
  lead:i = strchar:i(value, start)
  finish:i = start + 1
  if (lead >= 194 && lead <= 244) ithen
    width:i = lead < 224 ? 2 : (lead < 240 ? 3 : 4)
    if (start + width <= length) ithen
      while (finish < start + width) do
        byte:i = strchar:i(value, finish)
        if (byte < 128 || byte >= 192) ithen
          finish = start + 1
          break
        endif
        finish += 1
      od
    endif
  endif
  xout finish
endop

opcode MalStringCharacter(value:S, index:i):MalValue
  result:MalValue init MalMkValue($MAL_NIL_TYPE)
  length:i = strlen(value)
  if (index >= 0 && index < length) ithen
    offset:i = 0
    position:i = 0
    while (offset < length && position < index) do
      offset = MalStringCharacterEnd(value, offset, length)
      position += 1
    od
    if (offset < length) ithen
      result init MalMkString(strsub(value, offset, MalStringCharacterEnd(value, offset, length)))
    endif
  endif
  xout result
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
  valueType:i = $MAL_KEYWORD_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalMapFindKey(mapValue:MalValue, key:MalValue):i
  result:i = -1
  entryCount:i = int(mapValue.length / 2)

  if (entryCount > 0) ithen
    for entryIndex in [0 ... entryCount - 1] do
      keyIndex:i = entryIndex * 2

      if (MalEquals(MalAt(mapValue, keyIndex), key) == 1) ithen
        result = keyIndex
        break
      endif
    od
  endif

  xout result
endop

opcode MalMapAssoc(mapValue:MalValue, key:MalValue, value:MalValue):MalValue
  valueType:i = $MAL_HASH_MAP_TYPE
  zero:i = 0
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

  result:MalValue init valueType, zero, "", entries, \
    malEmptyEnvs, malEmptyValues, newLength, zero, zero
  xout result
endop

opcode MalMapDissoc(mapValue:MalValue, key:MalValue):MalValue
  valueType:i = $MAL_HASH_MAP_TYPE
  zero:i = 0
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

    result:MalValue init valueType, zero, "", entries, \
      malEmptyEnvs, malEmptyValues, newLength, zero, zero
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
  valueType:i = $MAL_LIST_TYPE
  zero:i = 0
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) ithen
    for index in [0 ... entryCount - 1] do
      values[index] MalAt mapValue, index * 2
    od
  endif

  result:MalValue init valueType, zero, "", values, malEmptyEnvs, \
    malEmptyValues, entryCount, zero, zero
  xout result
endop

opcode MalMapValues(mapValue:MalValue):MalValue
  valueType:i = $MAL_LIST_TYPE
  zero:i = 0
  entryCount:i = int(mapValue.length / 2)
  values:MalValue[] init entryCount

  if (entryCount > 0) ithen
    for index in [0 ... entryCount - 1] do
      values[index] MalAt mapValue, index * 2 + 1
    od
  endif

  result:MalValue init valueType, zero, "", values, malEmptyEnvs, \
    malEmptyValues, entryCount, zero, zero
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
  valueType:i = $MAL_ATOM_TYPE
  zero:i = 0
  capacity:i = lenarray(malAtomValues)

  if (malAtomCount >= capacity) ithen
    preserved:MalValue[] init capacity
    versions:i[] init capacity

    if (malAtomCount > 0) ithen
      for index in [0 ... malAtomCount - 1] do
        preserved[index] init malAtomValues[index]
        versions[index] = malAtomVersions[index]
      od
    endif

    newCapacity:i = capacity == 0 ? 8 : capacity * 2
    malAtomValues init newCapacity
    malAtomVersions init newCapacity

    if (malAtomCount > 0) ithen
      for index in [0 ... malAtomCount - 1] do
        malAtomValues[index] init preserved[index]
        malAtomVersions[index] = versions[index]
      od
    endif
  endif

  atomId:i = malAtomCount
  malAtomCount += 1
  malAtomValues[atomId] init value
  malAtomVersions[atomId] = 0

  val:MalValue init valueType, atomId, "", malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalAtomValue(atom:MalValue):MalValue
  xout malAtomValues[atom.number]
endop

opcode MalAtomSetValue(atom:MalValue, value:MalValue):MalValue
  malAtomValues[atom.number] init value
  malAtomVersions[atom.number] += 1
  xout value
endop

opcode MalMkBuiltin(name:S):MalValue
  valueType:i = $MAL_BUILTIN_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalMkBuiltinOperator(name:S):MalValue
  valueType:i = $MAL_BUILTIN_OPERATOR_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
  xout val
endop

opcode MalMkBuiltinOpcode(name:S):MalValue
  valueType:i = $MAL_BUILTIN_OPCODE_TYPE
  zero:i = 0
  val:MalValue init valueType, zero, name, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
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

opcode MalRegisterFunction(definition:MalValue):MalValue
  valueType:i = $MAL_FUNCTION_TYPE
  two:i = 2
  zero:i = 0
  MalFunctionEnsureCapacity()

  functionId:i = malFunctionCount
  malFunctionCount += 1
  malFunctionDefinitions[functionId] init definition

  handle:MalValue init valueType, functionId, "", \
    malEmptyValues, malEmptyEnvs, malEmptyValues, two, zero, zero
  xout handle
endop

opcode MalMkFunction(params:MalValue, body:MalValue):MalValue
  definition:MalValue init MalMkValue($MAL_FUNCTION_TYPE)
  definition init MalAppendValue(definition, params)
  definition init MalAppendValue(definition, MalInternAst(body))
  xout MalRegisterFunction(definition)
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
  length:i = strlen(token)
  index:i = 0
  digitCount:i = 0
  periodSeen:i = 0
  exponentSeen:i = 0
  first:i = strchar:i(token, 0)
  if (first == $MAL_MINUS_TOKEN || first == $MAL_PLUS_TOKEN) ithen
    index += 1
  endif
  while (index < length) do
    character:i = strchar:i(token, index)
    if (character >= 48 && character <= 57) ithen
      digitCount += 1
    elseif (character == $MAL_PERIOD_TOKEN && digitCount > 0 && periodSeen == 0 && exponentSeen == 0) ithen
      periodSeen = 1
    elseif ((character == 101 || character == 69) && digitCount > 0 && exponentSeen == 0) ithen
      exponentSeen = 1
      digitCount = 0
      if (index + 1 < length) ithen
        sign:i = strchar:i(token, index + 1)
        if (sign == $MAL_MINUS_TOKEN || sign == $MAL_PLUS_TOKEN) ithen
          index += 1
        endif
      endif
    else
      digitCount = 0
      break
    endif
    index += 1
  od
  xout digitCount > 0 ? 1 : 0
endop
