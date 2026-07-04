opcode MalMkError(message:S):MalValue
  v:MalValue = MalMkValue(giERROR_TYPE)
  v.string = message
  xout v
endop
