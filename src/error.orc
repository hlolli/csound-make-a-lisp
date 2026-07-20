declare pr_str(ast:MalValue):(S)

opcode MalMkError(message:S):MalValue
  v:MalValue init $MAL_ERROR_TYPE, 0, message, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, 0, 0, 0
  xout v
endop

opcode MalMkThrown(value:MalValue):MalValue
  message:S init sprintf("Error: %s", pr_str(value))
  v:MalValue MalMkError message
  v MalAppendValue v, value
  xout v
endop

opcode MalErrorPayload(error:MalValue):MalValue
  if (error.type == $MAL_ERROR_TYPE && error.length > 0) ithen
    value:MalValue MalAt error, 0
  else
    value:MalValue MalMkString error.string
  endif

  xout value
endop
