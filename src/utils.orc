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
  list:MalValue[] = destination.list
  list[destination.length] = value
  destination.length += 1
  destination.list = list
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
  iascii = strchar:i(token, 0)
  itokenLen = strlen(token)
  ires = 0
  if (iascii >= 48 && iascii < 58) then
    ires = 1
  elseif (iascii == $MAL_MINUS_TOKEN && itokenLen > 1) then
    inext = strchar:i(token, 1)
    if (inext >= 48 && inext < 58) then
      ires = 1
    endif
  endif
  xout ires
endop
