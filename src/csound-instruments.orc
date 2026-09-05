;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

opcode MalCsoundParamBindings(params:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_VECTOR_TYPE)

  if (params.type != $MAL_LIST_TYPE && params.type != $MAL_VECTOR_TYPE) ithen
    result init MalMkError("csound/definst: parameters must be a list or vector")
  elseif (params.length % 2 != 0) ithen
    result init MalMkError("csound/definst: parameters must contain name/default pairs")
  else
    result init MalAppendValue(result, MalMkSymbol("p2"))
    result init MalAppendValue(result, MalMkCsoundParam(2))
    result init MalAppendValue(result, MalMkSymbol("p3"))
    result init MalAppendValue(result, MalMkCsoundParam(3))

    if (params.length > 0) ithen
      for index in [0 ... int(params.length / 2) - 1] do
        name:MalValue init MalAt(params, index * 2)
        defaultValue:MalValue init MalAt(params, index * 2 + 1)

        if (name.type != $MAL_SYMBOL_TYPE) ithen
          result init MalMkError("csound/definst: parameter names must be symbols")
          break
        elseif (strcmp(name.string, "p2") == 0 || \
                strcmp(name.string, "p3") == 0) ithen
          result init MalMkError("csound/definst: p2 and p3 are implicit parameters")
          break
        elseif (defaultValue.type != $MAL_NUMBER_TYPE) ithen
          result init MalMkError("csound/definst: parameter defaults must be numbers")
          break
        else
          result init MalAppendValue(result, name)
          result init MalAppendValue(result, MalMkCsoundParam(index + 4))
        endif
      od
    endif
  endif

  xout result
endop

opcode MalCsoundIdentifierIsValid(value:MalValue):i
  valid:i = value.type == $MAL_SYMBOL_TYPE && strlen(value.string) > 0

  if (valid == 1) ithen
    for index in [0 ... strlen(value.string) - 1] do
      character:i = strchar:i(value.string, index)
      isLetter:i = (character >= 65 && character <= 90) || \
        (character >= 97 && character <= 122)
      isDigit:i = character >= 48 && character <= 57
      isUnderscore:i = character == 95

      if ((index == 0 && isLetter == 0 && isUnderscore == 0) || \
          (index > 0 && isLetter == 0 && isDigit == 0 && \
           isUnderscore == 0)) ithen
        valid = 0
        break
      endif
    od
  endif

  xout valid
endop

opcode MalCsoundDefaults(params:MalValue):MalValue
  defaults:MalValue init MalMkValue($MAL_LIST_TYPE)

  if (params.length > 0) ithen
    for index in [0 ... int(params.length / 2) - 1] do
      defaults init MalAppendValue(defaults, MalAt(params, index * 2 + 1))
    od
  endif

  xout defaults
endop

