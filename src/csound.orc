;; This Source Code Form is subject to the terms of the Mozilla Public
;; License, v. 2.0. If a copy of the MPL was not distributed with this
;; file, You can obtain one at https://mozilla.org/MPL/2.0/.

;; Graph payload: output types, stable identity, then arguments. Identity lets
;; code generation emit a shared stateful node once per instrument.
declare MalCsoundRenderValue(value:MalValue):(MalCsoundRender)
declare MalArityError(name:S, expected:i, actual:i):(MalValue)

opcode MalCsoundNumber(number:i):S
  ;; Source and score fields need full double precision; REPL printing rounds.
  xout sprintf("%.17g", number)
endop

opcode MalCsoundTypes(value:MalValue):S
  result:S init "invalid"
  if (value.type == $MAL_NUMBER_TYPE) ithen
    result init "i"
  elseif (value.type == $MAL_STRING_TYPE) ithen
    result init "S"
  elseif (value.type == $MAL_CSOUND_NODE_TYPE) ithen
    types:MalValue init MalAt(value, 0)
    result init types.string
  endif
  xout result
endop

opcode MalCsoundTypeList(types:S):S[]
  result:S[] init 0
  if (strlen(types) > 0) ithen
    count:i = 1
    for index in [0 ... strlen(types) - 1] do
      if (strchar:i(types, index) == 44) ithen
        count += 1
      endif
    od
    result init count
    start:i = 0
    part:i = 0
    for index in [0 ... strlen(types)] do
      if (index == strlen(types) || strchar:i(types, index) == 44) ithen
        result[part] init strsub(types, start, index)
        part += 1
        start = index + 1
      endif
    od
  endif
  xout result
endop

opcode MalCsoundTypeCost(actual:S, expected:S):i
  result:i = -1
  if (strcmp(actual, expected) == 0) ithen
    result = 0
  elseif (strcmp(actual, "i") == 0 && strcmp(expected, "k") == 0) ithen
    result = 1
  endif
  ;; Arrays match exactly. A scalar promotion never changes an array's rate.
  xout result
endop

opcode MalMkCsoundNode(name:S, kind:i, types:S, args:MalValue):MalValue
  node:MalValue init MalMkValue($MAL_CSOUND_NODE_TYPE)
  node.string init name
  node.number = kind
  node init MalAppendValue(node, MalMkString(types))
  node init MalAppendValue(node, MalMkNumber(malCsoundNodeCount))
  malCsoundNodeCount += 1
  if (args.length > 0) ithen
    for index in [0 ... args.length - 1] do
      node init MalAppendValue(node, MalAt(args, index))
    od
  endif
  xout node
endop

opcode MalMkCsoundParam(index:i):MalValue
  args:MalValue init MalMkValue($MAL_LIST_TYPE)
  xout MalMkCsoundNode(sprintf("p%d", index), $MAL_CSOUND_PARAM_NODE, "i", args)
endop

opcode MalIsCsoundNode(value:MalValue):i
  valueType:i = value.type
  result:i = valueType == $MAL_CSOUND_NODE_TYPE
  xout result
endop

opcode MalMkCsoundInfix(operator:S, args:MalValue):MalValue
  left:S init MalCsoundTypes(MalAt(args, 0))
  right:S init MalCsoundTypes(MalAt(args, 1))
  if (strlen(left) != 1 || strlen(right) != 1 || \
      strindex("ika", left) < 0 || strindex("ika", right) < 0) ithen
    result:MalValue init MalMkError(sprintf( \
      "%s: expected scalar numeric operands, got (%s, %s)", operator, left, right))
  else
    rate:S init "i"
    if (strcmp(left, "a") == 0 || strcmp(right, "a") == 0) ithen
      rate init "a"
    elseif (strcmp(left, "k") == 0 || strcmp(right, "k") == 0) ithen
      rate init "k"
    endif
    result init MalMkCsoundNode(operator, $MAL_CSOUND_INFIX_NODE, rate, args)
  endif
  xout result
endop

;; Signature fields: outputs, required argument count; payload: fixed input
;; types, repeated group types, minimum group count. Omitted arguments are left
;; out of the emitted call, so Csound supplies its own defaults.
opcode MalCsoundSignature(outputs:S, inputs:S, required:i, \
                          repeated:S, minGroups:i):MalValue
  value:MalValue init MalMkValue($MAL_VECTOR_TYPE)
  value.string init outputs
  value.number = required
  value init MalAppendValue(value, MalMkString(inputs))
  value init MalAppendValue(value, MalMkString(repeated))
  value init MalAppendValue(value, MalMkNumber(minGroups))
  xout value
endop

opcode MalMkCsoundOpcode(name:S, preferred:S):MalValue
  value:MalValue init MalMkValue($MAL_BUILTIN_OPCODE_TYPE)
  value.string init name
  value init MalAppendValue(value, MalMkString(preferred))
  xout value
endop

opcode MalCsoundOutputs(value:MalValue):MalValue
  types:S[] init MalCsoundTypeList(MalCsoundTypes(value))
  result:MalValue init MalMkValue($MAL_VECTOR_TYPE)
  if (value.type != $MAL_CSOUND_NODE_TYPE || lenarray(types) == 0) ithen
    result init MalMkError("csound/outputs: expected a graph with outputs")
  else
    for index in [0 ... lenarray(types) - 1] do
      args:MalValue init MalMkList2(value, MalMkNumber(index))
      projection:MalValue init MalMkCsoundNode(value.string, \
        $MAL_CSOUND_PROJECTION_NODE, types[index], args)
      result init MalAppendValue(result, projection)
    od
  endif
  xout result
endop

opcode MalCsoundFlatten(args:MalValue):MalValue
  result:MalValue init MalMkValue($MAL_LIST_TYPE)
  if (args.length > 0) ithen
    for index in [0 ... args.length - 1] do
      arg:MalValue init MalAt(args, index)
      types:S init MalCsoundTypes(arg)
      if (strindex(types, ",") >= 0) ithen
        outputs:MalValue init MalCsoundOutputs(arg)
        for outputIndex in [0 ... outputs.length - 1] do
          result init MalAppendValue(result, MalAt(outputs, outputIndex))
        od
      else
        result init MalAppendValue(result, arg)
      endif
    od
  endif
  xout result
endop

opcode MalCsoundSignatureCost(signature:MalValue, args:MalValue):i
  fixedValue:MalValue init MalAt(signature, 0)
  repeatValue:MalValue init MalAt(signature, 1)
  minValue:MalValue init MalAt(signature, 2)
  fixed:S[] init MalCsoundTypeList(fixedValue.string)
  repeated:S[] init MalCsoundTypeList(repeatValue.string)
  fixedCount:i = lenarray(fixed)
  repeatCount:i = lenarray(repeated)
  cost:i = 0
  if (args.length < signature.number) ithen
    cost = -1
  elseif (repeatCount == 0 && args.length > fixedCount) ithen
    cost = -1
  elseif (repeatCount > 0) ithen
    extra:i = args.length - fixedCount
    if (extra < minValue.number * repeatCount || extra % repeatCount != 0) ithen
      cost = -1
    endif
  endif
  if (cost >= 0 && args.length > 0) ithen
    for index in [0 ... args.length - 1] do
      if (index < fixedCount) ithen
        expected:S init fixed[index]
      else
        expected init repeated[(index - fixedCount) % repeatCount]
      endif
      actual:S init MalCsoundTypes(MalAt(args, index))
      argumentCost:i = MalCsoundTypeCost(actual, expected)
      if (argumentCost < 0) ithen
        cost = -1
        break
      endif
      cost += argumentCost
    od
  endif
  xout cost
endop

opcode MalApplyCsoundOpcode(fn:MalValue, rawArgs:MalValue):MalValue
  args:MalValue init MalCsoundFlatten(rawArgs)
  selected:i = -1
  bestCost:i = 1000000
  ambiguous:i = 0
  preference:MalValue init MalAt(fn, 0)
  if (fn.length > 1) ithen
    for index in [1 ... fn.length - 1] do
      signature:MalValue init MalAt(fn, index)
      if (strlen(preference.string) == 0 || \
          strcmp(preference.string, signature.string) == 0) ithen
        cost:i = MalCsoundSignatureCost(signature, args)
        if (cost >= 0 && cost < bestCost) ithen
          bestCost = cost
          selected = index
          ambiguous = 0
        elseif (cost >= 0 && cost == bestCost) ithen
          ambiguous = 1
        endif
      endif
    od
  endif
  if (selected < 0) ithen
    actual:S init ""
    if (args.length > 0) ithen
      for index in [0 ... args.length - 1] do
        if (index > 0) ithen
          actual strcat actual, ", "
        endif
        actual strcat actual, MalCsoundTypes(MalAt(args, index))
      od
    endif
    result:MalValue init MalMkError(sprintf( \
      "csound/%s: no matching signature for (%s)", fn.string, actual))
  elseif (ambiguous == 1) ithen
    result init MalMkError(sprintf( \
      "csound/%s: ambiguous signature; select outputs with csound/at-rate", fn.string))
  else
    signature:MalValue init MalAt(fn, selected)
    result init MalMkCsoundNode(fn.string, $MAL_CSOUND_CALL_NODE, signature.string, args)
  endif
  xout result
endop

opcode MalCsoundTypeName(name:S):S
  result:S init name
  if (strlen(name) == 7 && strcmp(strsub(name, 1), "-array") == 0) ithen
    result init sprintf("%s[]", strsub(name, 0, 1))
  endif
  xout result
endop

opcode MalCsoundTypeKeyword(name:S):MalValue
  result:S init name
  if (strlen(name) == 3 && strcmp(strsub(name, 1), "[]") == 0) ithen
    result init sprintf("%s-array", strsub(name, 0, 1))
  endif
  xout MalMkKeyword(result)
endop

opcode MalCsoundAtRate(rate:MalValue, fn:MalValue):MalValue
  selector:S init ""
  if (rate.type == $MAL_KEYWORD_TYPE) ithen
    selector init MalCsoundTypeName(rate.string)
  elseif (rate.type == $MAL_VECTOR_TYPE && rate.length > 0) ithen
    for index in [0 ... rate.length - 1] do
      part:MalValue init MalAt(rate, index)
      if (part.type != $MAL_KEYWORD_TYPE) ithen
        selector init "invalid"
        break
      endif
      if (index > 0) ithen
        selector strcat selector, ","
      endif
      selector strcat selector, MalCsoundTypeName(part.string)
    od
  endif
  result:MalValue init MalMkError("csound/at-rate: expected output type keyword or vector and opcode function")
  if (strlen(selector) > 0 && fn.type == $MAL_BUILTIN_OPCODE_TYPE) ithen
    found:i = 0
    if (fn.length > 1) ithen
      for index in [1 ... fn.length - 1] do
        signature:MalValue init MalAt(fn, index)
        if (strcmp(selector, signature.string) == 0) ithen
          found = 1
        endif
      od
    endif
    if (found == 0) ithen
      result init MalMkError(sprintf("csound/%s: unsupported outputs %s", fn.string, selector))
    else
      result init MalMkCsoundOpcode(fn.string, selector)
      for index in [1 ... fn.length - 1] do
        result init MalAppendValue(result, MalAt(fn, index))
      od
    endif
  endif
  xout result
endop

opcode MalCsoundArray(rate:MalValue, values:MalValue):MalValue
  result:MalValue init MalMkError("csound/array: expected :i, :k, :a or :S and a vector")
  if (rate.type == $MAL_KEYWORD_TYPE && strlen(rate.string) == 1 && \
      strindex("ikaS", rate.string) >= 0 && values.type == $MAL_VECTOR_TYPE) ithen
    arrayType:S init sprintf("%s[]", rate.string)
    result init MalMkCsoundNode("array", $MAL_CSOUND_ARRAY_NODE, arrayType, values)
    if (values.length > 0) ithen
      for index in [0 ... values.length - 1] do
        actual:S init MalCsoundTypes(MalAt(values, index))
        if (MalCsoundTypeCost(actual, rate.string) < 0) ithen
          result init MalMkError(sprintf("csound/array: element %d expected %s, got %s", \
            index, rate.string, actual))
          break
        endif
      od
    endif
  endif
  xout result
endop

opcode MalCsoundArrayAt(array:MalValue, index:MalValue):MalValue
  types:S init MalCsoundTypes(array)
  result:MalValue init MalMkError("csound/aget: expected a one-dimensional array and an init-rate index")
  if (strlen(types) == 3 && strcmp(strsub(types, 1), "[]") == 0 && \
      strcmp(MalCsoundTypes(index), "i") == 0) ithen
    if (index.type == $MAL_NUMBER_TYPE && (index.number < 0 || \
        int(index.number) != index.number)) ithen
      result init MalMkError("csound/aget: index must be a nonnegative integer")
    elseif (array.number == $MAL_CSOUND_ARRAY_NODE && \
            index.type == $MAL_NUMBER_TYPE && index.number >= array.length - 2) ithen
      result init MalMkError("csound/aget: index out of bounds")
    else
      args:MalValue init MalMkList2(array, index)
      result init MalMkCsoundNode("aget", $MAL_CSOUND_INDEX_NODE, strsub(types, 0, 1), args)
    endif
  endif
  xout result
endop

opcode MalCsoundType(value:MalValue):MalValue
  types:S init MalCsoundTypes(value)
  if (strcmp(types, "invalid") == 0) ithen
    result:MalValue init MalMkError("csound/type: expected a graph value, number or string")
  elseif (strlen(types) == 0) ithen
    result init MalMkValue($MAL_NIL_TYPE)
  elseif (strindex(types, ",") < 0) ithen
    result init MalCsoundTypeKeyword(types)
  else
    result init MalMkValue($MAL_VECTOR_TYPE)
    parts:S[] init MalCsoundTypeList(types)
    for index in [0 ... lenarray(parts) - 1] do
      result init MalAppendValue(result, MalCsoundTypeKeyword(parts[index]))
    od
  endif
  xout result
endop

opcode MalMkCsoundInstrument(name:S, defaults:MalValue):MalValue
  instrument:MalValue init defaults
  instrument.type = $MAL_CSOUND_INSTRUMENT_TYPE
  instrument.string init name
  xout instrument
endop

#include "src/csound-instruments.orc"
#include "src/csound-render.orc"
#include "src/csound-events.orc"
#include "src/csound-opcodes.orc"
