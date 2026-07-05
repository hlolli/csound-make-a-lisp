opcode MalMkError(message:S):MalValue
  v:MalValue = MalMkValue($MAL_ERROR_TYPE)
  v.string = message
  xout v
endop
