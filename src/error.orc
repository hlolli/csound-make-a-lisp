;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

declare pr_str(ast:MalValue):(S)

opcode MalMkError(message:S):MalValue
  valueType:i = $MAL_ERROR_TYPE
  zero:i = 0
  v:MalValue init valueType, zero, message, malEmptyValues, \
    malEmptyEnvs, malEmptyValues, zero, zero, zero
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
