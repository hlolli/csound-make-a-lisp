#include "constants.orc"
#include "types.orc"

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
  print destination.length
  destination.length += 1
  destination.list[destination.length] = value
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

opcode MalIsNumericString(token:S):i
  iascii = strchar(token, 0)
  if (iascii >= 48 && iascii < 58) then
    xout 1
  else
    xout 0
  endif
endop
