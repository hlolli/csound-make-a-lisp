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
  val:MalValue init type, 0, "", list, 0
  xout(val)
endop

opcode MalMkSymbol(name:S):MalValue
  val:MalValue = MalMkValue($MAL_SYMBOL_TYPE)
  val.string = name
  xout val
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
    value.length, reader.peek, reader.position, reader.tokens, reader.length, \
    reader.done
  xout result
endop

opcode MalReadResultValue(result:MalReadResult):MalValue
  value:MalValue init result.type, result.number, result.string, result.list, \
    result.length
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

  while (indx < itokenLen && iinvalid == 0) do
    ichar = strchar:i(token, indx)

    if (ichar >= 48 && ichar < 58) then
      idigitCount += 1
    elseif (ichar == $MAL_PERIOD_TOKEN && iperiodCount == 0 && idigitCount > 0) then
      iperiodCount = 1
    else
      iinvalid = 1
    endif

    indx += 1
  od

  if (idigitCount > 0 && iinvalid == 0) then
    ires = 1
  endif

  xout ires
endop
