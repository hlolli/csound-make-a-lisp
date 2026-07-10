declare pr_str(ast:MalValue):(S)

opcode MalMkError(message:S):MalValue
  v:MalValue = MalMkValue($MAL_ERROR_TYPE)
  v.string = message
  xout v
endop

opcode MalMkThrown(value:MalValue):MalValue
  message:S = sprintf("Error: %s", pr_str(value))
  v:MalValue = MalMkError(message)
  v = MalAppendValue(v, value)
  xout v
endop

opcode MalErrorPayload(error:MalValue):MalValue
  if (error.type == $MAL_ERROR_TYPE && error.length > 0) then
    value:MalValue = error.list[0]
  else
    value:MalValue = MalMkString(error.string)
  endif

  xout value
endop
